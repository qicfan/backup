import { TaskItemStatus } from "../typing";
import { dataSharePredicates } from "@kit.ArkData";
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { TaskItem } from "../models/TaskItem";
import { image } from "@kit.ImageKit";
import { fileSize } from "./tools";
import { fileIo } from "@kit.CoreFileKit";
import { BackupServer } from "./server";
import { ServerConfig } from "../models/Server";
import { Config } from "../models/Config";

export class Photos {
  /**
   * 查询未备份的照片列表
   * @param number lastTimestamp 最后一次备份的时间戳，只取添加时间大于等于该指的照片
   */
  static async getPhotos(ctx: Context, lastTimestamp: number, page: number = 1,
    pageSize: number = 100): Promise<TaskItem[]> {
    let backupServer = BackupServer.getInstance()
    backupServer.updateConfig(ServerConfig.getInstance(), Config.getInstance())
    const items: TaskItem[] = []
    // 循环直到没有数据
    let predicates = new dataSharePredicates.DataSharePredicates();
    const offset = (page - 1) * pageSize;
    predicates.limit(pageSize, offset).orderByDesc('date_added')
    let phAccessHelper = photoAccessHelper.getPhotoAccessHelper(ctx);
    let fetchRs: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset>;
    try {
      fetchRs = await phAccessHelper.getAssets({
        fetchColumns: ['uri', 'display_name', 'media_type', 'subtype', 'date_added', 'date_modified', 'size', 'mime_type'],
        predicates: predicates
      })
      if (fetchRs.getCount() <= 0) {
        return items;
      }
    } catch (e) {
      let err = e as BusinessError
      console.log(`查询照片失败，code=${err.code}, msg=${err.message}`)
      return items;
    }
      while (!fetchRs.isAfterLast()) {
        let ps: photoAccessHelper.PhotoAsset;
        try {
          ps = await fetchRs.getNextObject()
        } catch (e) {
          let err = e as BusinessError;
          console.log(`获取photo assets失败，code=${err.code}, msg=${err.message}`)
          continue
        }
        const item = new TaskItem()
        item.dateAdded = ps.get('date_added') as number;
        // console.log(`是否跳过文件，文件添加时间戳：${item.dateAdded}, 最后一次备份时间：${lastTimestamp}`)
        if (item.dateAdded < lastTimestamp) {
          continue;
        }
        item.uri = ps.uri;
        item.photoType = ps.photoType as number;
        item.subType = ps.get('subtype') as number;
        item.name = ps.displayName;
        item.createdAt = ps.get('date_modified') as number;
        item.size = ps.get('size') as number;
        item.status = TaskItemStatus.WAIT;
        item.makeUri(ctx);
        // let realPath = item.remoteUri
        //1. 先通过path判断是否存在
        let exists = await backupServer.exists(item.remoteUri, false, true)
        if (exists) {
          continue
        } else {
          console.log(`通过path查询到文件没有备份：${item.remoteUri}`)
        }
        //2. 通过uri查询是否存在
        exists = await backupServer.exists(ps.uri, true, false, item.size)
        if (exists) {
          continue
        } else {
          console.log(`通过fileUri查询到文件没有备份：${item.uri}`)
        }
        //3. 使用checksum来判断是否存在
        exists = await backupServer.checksumExists(ps.uri)
        if (exists) {
          continue
        } else {
          console.log(`通过checksum查询到文件没有备份: ${item.remoteUri}`)
        }
        const rs = await item.save();
        if (rs) {
          items.push(item);
        }
      }
    fetchRs.close();
    return items;
  }

  // 通过uri获取PhotoAsset做进一步的展示
  static async getPhotoAssetByUri(ctx: Context, uri: string): Promise<photoAccessHelper.PhotoAsset | undefined> {
    return new Promise(async (resolve, reject) => {
      let predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
      predicates.equalTo('uri', uri);
      let fetchOptions: photoAccessHelper.FetchOptions = {
        fetchColumns: [],
        predicates: predicates
      };
      let phAccessHelper = photoAccessHelper.getPhotoAccessHelper(ctx);
      let assetResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> = await phAccessHelper.getAssets(fetchOptions);
      if (!assetResult || assetResult.getCount() <= 0) {
        resolve(undefined)
        return;
      }
      let asset: photoAccessHelper.PhotoAsset = await assetResult.getFirstObject();
      resolve(asset);
    });
  }

  static async getMovingPhoto(context: Context, photoAsset: photoAccessHelper.PhotoAsset): Promise<photoAccessHelper.MovingPhoto> {
    return new Promise((resolve, reject) => {
      photoAccessHelper.MediaAssetManager.requestMovingPhoto(context, photoAsset, {
        deliveryMode: photoAccessHelper.DeliveryMode.FAST_MODE
      }, {
        async onDataPrepared(movingPhoto: photoAccessHelper.MovingPhoto) {
          if (movingPhoto !== undefined) {
            // 应用可自定义对movingPhoto的处理逻辑。
            console.info('request moving photo successfully, uri: ' + movingPhoto.getUri());
            resolve(movingPhoto)
          } else {
            resolve(undefined)
          }
        }
      })
    })

  }

  // 通过uri获取PhotoAsset做进一步的展示
  static async saveMovingPhotoVideoByAsset(ctx: Context, asset: photoAccessHelper.PhotoAsset, videoUri: string): Promise<number> {
    return new Promise(async (resolve, reject) => {
      let requestOptions: photoAccessHelper.RequestOptions = {
        deliveryMode: photoAccessHelper.DeliveryMode.HIGH_QUALITY_MODE,
      }

      try {
        await photoAccessHelper.MediaAssetManager.requestMovingPhoto(ctx, asset, requestOptions, {
          onDataPrepared: (movingPhoto: photoAccessHelper.MovingPhoto) => {
            if (movingPhoto === undefined) {
              console.error("读取动态图片数据出错，请检查该图片是否存在或重试")
              return resolve(-1);
            }
            // console.info(`读取动态图片${asset.get('uri')}的视频，视频本地路径:${videoUri}`)
            movingPhoto.requestContent(photoAccessHelper.ResourceType.VIDEO_RESOURCE, videoUri).then(() => {
              // 读取文件大小返回
              const size = fileSize(videoUri);
              resolve(size)
            }).catch((err: BusinessError) => {
              console.error(`动态图片保存视频失败, error code is ${err.code}, message is ${err.message}`);
              reject(err)
            })
          }
        });
      } catch (err) {
        console.error(`failed to request moving photo, error code is ${err.code}, message is ${err.message}`);
        reject(err)
      }
    });
  }

  // 获取图片的内容
  static async getPixelMapByAsset(ctx: Context, asset: photoAccessHelper.PhotoAsset | undefined): Promise<image.PixelMap | undefined> {
    return new Promise(async (resolve, reject) => {
      if (!asset) {
        resolve(undefined);
        return;
      }
      const requestOptions: photoAccessHelper.RequestOptions = {
        deliveryMode: photoAccessHelper.DeliveryMode.FAST_MODE,
      }
      try {
        let requestId: string = await photoAccessHelper.MediaAssetManager.requestImage(ctx, asset, requestOptions, {
          onDataPrepared: (imgSource: image.ImageSource) => {
            imgSource.createPixelMap().then((pm) => resolve(pm)).catch((err: BusinessError) => reject(err))
          }
        });
      } catch (err) {
        console.error(`failed to request moving photo, error code is ${err.code}, message is ${err.message}`);
        reject(err)
      }
    });
  }

  static async saveVideo(ctx: Context, uri: string, videoUri: string, size: number): Promise<string> {
    return new Promise(async (resolve, reject) => {
      let predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
      predicates.equalTo(photoAccessHelper.PhotoKeys.PHOTO_TYPE, photoAccessHelper.PhotoType.VIDEO).and().equalTo('uri', uri);
      let fetchOptions: photoAccessHelper.FetchOptions = {
        fetchColumns: [],
        predicates: predicates
      };
      let phAccessHelper = photoAccessHelper.getPhotoAccessHelper(ctx);
      let assetResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> = await phAccessHelper.getAssets(fetchOptions);
      if (!assetResult || assetResult.getCount() <= 0) {
        resolve("无法查询到视频数据")
        return;
      }
      let asset: photoAccessHelper.PhotoAsset = await assetResult.getFirstObject();
      let requestOptions: photoAccessHelper.RequestOptions = {
        deliveryMode: photoAccessHelper.DeliveryMode.HIGH_QUALITY_MODE,
        compatibleMode: photoAccessHelper.CompatibleMode.ORIGINAL_FORMAT_MODE
      }
      // 直接复制文件
      // try {
      //   if (copyImg2Sandbox(asset.uri, videoUri, size)) {
      //     console.log(`导出视频成功：${asset.uri} => ${videoUri}`)
      //     resolve('success')
      //   } else {
      //     reject('failed')
      //   }
      // } catch (e) {
      //   console.error('Failed to copy image or video to sandbox. And the error is: ' + e);
      //   reject(e)
      // } finally {
      //
      // }

      try {
        await photoAccessHelper.MediaAssetManager.requestVideoFile(ctx, asset, requestOptions, videoUri, {
          onDataPrepared: (success: boolean) => {
            if (!success) {
              resolve("读取视频数据出错，请检查该视频是否存在或重试");
              return ;
            }
            console.log(`导出视频成功：${asset.uri} => ${videoUri}`)
            resolve('success');
          }
        });
      } catch (err) {
        console.error(`failed to request video, error code is ${err.code}, message is ${err.message}`);
        reject(err)
      }
    });
  }

  static async saveImage(ctx: Context, uri: string, imageUri: string, size: number): Promise<string> {
    return new Promise(async (resolve, reject) => {
      // try {
      //   if (copyImg2Sandbox(uri, imageUri, size)) {
      //     resolve('success')
      //   } else {
      //     reject('failed')
      //   }
      // } catch (e) {
      //   console.error('Failed to copy image or video to sandbox. And the error is: ' + e);
      //   reject(e)
      // }
      let file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      // console.info('file fd: ' + file.fd);
      //根据文件fd创建imagSource
      const imageSource: image.ImageSource = image.createImageSource(file.fd);
      const keys = [
      // 基础信息
        image.PropertyKey.IMAGE_DESCRIPTION,
        image.PropertyKey.MAKE,
        image.PropertyKey.MODEL,
        image.PropertyKey.ORIENTATION,
        image.PropertyKey.X_RESOLUTION,
        image.PropertyKey.Y_RESOLUTION,
        image.PropertyKey.RESOLUTION_UNIT,
        image.PropertyKey.SOFTWARE,
        image.PropertyKey.DATE_TIME,
        image.PropertyKey.OFFSET_TIME,

        // GPS
        image.PropertyKey.GPS_VERSION_ID,
        image.PropertyKey.GPS_LATITUDE_REF,
        image.PropertyKey.GPS_LATITUDE,
        image.PropertyKey.GPS_LONGITUDE_REF,
        image.PropertyKey.GPS_LONGITUDE,
        image.PropertyKey.GPS_ALTITUDE_REF,
        image.PropertyKey.GPS_ALTITUDE,
        image.PropertyKey.GPS_STATUS,
        image.PropertyKey.GPS_MAP_DATUM,

        // 拍摄参数
        image.PropertyKey.EXPOSURE_TIME,
        image.PropertyKey.F_NUMBER,
        image.PropertyKey.EXPOSURE_PROGRAM,
        image.PropertyKey.ISO_SPEED_RATINGS,
        image.PropertyKey.SENSITIVITY_TYPE,
        image.PropertyKey.EXIF_VERSION,
        image.PropertyKey.DATE_TIME_ORIGINAL,
        image.PropertyKey.DATE_TIME_DIGITIZED,
        image.PropertyKey.SHUTTER_SPEED,
        image.PropertyKey.APERTURE_VALUE,
        image.PropertyKey.EXPOSURE_BIAS_VALUE,
        image.PropertyKey.MAX_APERTURE_VALUE,
        image.PropertyKey.METERING_MODE,
        image.PropertyKey.LIGHT_SOURCE,
        image.PropertyKey.FLASH,
        image.PropertyKey.FOCAL_LENGTH,
        image.PropertyKey.COLOR_SPACE,
        image.PropertyKey.PIXEL_X_DIMENSION,
        image.PropertyKey.PIXEL_Y_DIMENSION,
        image.PropertyKey.WHITE_BALANCE,
        image.PropertyKey.DIGITAL_ZOOM_RATIO,
        image.PropertyKey.SCENE_CAPTURE_TYPE,
        image.PropertyKey.GAIN_CONTROL,
        image.PropertyKey.CONTRAST,
        image.PropertyKey.SATURATION,
        image.PropertyKey.SHARPNESS,
        image.PropertyKey.BODY_SERIAL_NUMBER,
        image.PropertyKey.LENS_SPECIFICATION
      ]
      imageSource.getImageProperties(keys).then((data) => {
        console.info(JSON.stringify(data));
      }).catch((err: BusinessError) => {
        console.error(JSON.stringify(err));
      });
      let info = imageSource.getImageInfoSync(0)
      // 写入文件
      let newFile = fileIo.openSync(imageUri, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      const imagePackerApi = image.createImagePacker();
      let packOpts : image.PackingOption = { format:info.mimeType, quality: 100, needsPackProperties: true, desiredDynamicRange: image.PackingDynamicRange.AUTO };
      imagePackerApi.packToFile(imageSource, newFile.fd, packOpts).then(() => {
        console.info(`导出普通照片成功：${uri} => ${imageUri}`)
        resolve('success')
      }).catch((error : BusinessError) => {
        console.error('Failed to pack the image. And the error is: ' + error);
        reject(error)
      }).finally(()=>{
        fileIo.closeSync(file.fd);
        fileIo.closeSync(newFile.fd)
        imageSource.release()
        imagePackerApi.release()
      })
      // // 关闭文件
      // let predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
      // predicates.equalTo(photoAccessHelper.PhotoKeys.PHOTO_TYPE, photoAccessHelper.PhotoType.IMAGE).and().equalTo('uri', uri);
      // let fetchOptions: photoAccessHelper.FetchOptions = {
      //   fetchColumns: [],
      //   predicates: predicates
      // };
      // let phAccessHelper = photoAccessHelper.getPhotoAccessHelper(ctx);
      // let assetResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> = await phAccessHelper.getAssets(fetchOptions);
      // if (!assetResult || assetResult.getCount() <= 0) {
      //   console.error("无法查询到图片数据")
      //   resolve("无法查询到图片数据");
      //   return;
      // }
      // let asset: photoAccessHelper.PhotoAsset = await assetResult.getFirstObject();
      // let requestOptions: photoAccessHelper.RequestOptions = {
      //   deliveryMode: photoAccessHelper.DeliveryMode.HIGH_QUALITY_MODE,
      //   compatibleMode: photoAccessHelper.CompatibleMode.ORIGINAL_FORMAT_MODE
      // }
      // try {
      //   await photoAccessHelper.MediaAssetManager.requestImageData(ctx, asset, requestOptions, {
      //     onDataPrepared: (data: ArrayBuffer) => {
      //       if (data === undefined) {
      //         console.error("读取图片数据出错，请检查该图片是否存在或重试")
      //         resolve("读取图片数据出错，请检查该图片是否存在或重试");
      //         return ;
      //       }
      //
      //       try {
      //         // 写入文件
      //         const destFile = fileIo.openSync(imageUri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      //         try {
      //           fileIo.statSync(destFile.fd);
      //           // fileIo.unlinkSync(imageUri);
      //         } catch (err) {
      //           console.error(`查询文件状态出错, error code is ${err.code}, message is ${err.message}`);
      //         }
      //         fileIo.writeSync(destFile.fd, data);
      //         fileIo.closeSync(destFile.fd);
      //         resolve('success');
      //       } catch (err) {
      //         console.error(`写入图片文件出错, error code is ${err.code}, message is ${err.message}`);
      //         reject(err)
      //       }
      //     }
      //   });
      // } catch (err) {
      //   console.error(`failed to request image, error code is ${err.code}, message is ${err.message}`);
      //   reject(err)
      // }
    });
  }

  // 将动态图片的图片和视频保存到本地沙箱文件
  static async saveMovingPhoto(ctx: Context, uri: string, imageUri: string, videoUri: string): Promise<string> {
    return new Promise(async (resolve, reject) => {
      let predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
      predicates.equalTo(photoAccessHelper.PhotoKeys.PHOTO_SUBTYPE, photoAccessHelper.PhotoSubtype.MOVING_PHOTO).and().equalTo('uri', uri);
      let fetchOptions: photoAccessHelper.FetchOptions = {
        fetchColumns: [],
        predicates: predicates
      };
      let phAccessHelper = photoAccessHelper.getPhotoAccessHelper(ctx);
      let assetResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> = await phAccessHelper.getAssets(fetchOptions);
      if (!assetResult || assetResult.getCount() <= 0) {
        resolve("无法查询到图片数据")
        return;
      }
      let asset: photoAccessHelper.PhotoAsset = await assetResult.getFirstObject();

      let requestOptions: photoAccessHelper.RequestOptions = {
        deliveryMode: photoAccessHelper.DeliveryMode.HIGH_QUALITY_MODE,
        compatibleMode: photoAccessHelper.CompatibleMode.ORIGINAL_FORMAT_MODE
      }

      try {
        await photoAccessHelper.MediaAssetManager.requestMovingPhoto(ctx, asset, requestOptions, {
          onDataPrepared: (movingPhoto: photoAccessHelper.MovingPhoto) => {
            if (movingPhoto === undefined) {
              resolve("读取动态图片数据出错，请检查该图片是否存在或重试")
            }
            // console.info(`读取动态图片${uri}，图片：${movingPhoto.getUri()}=>${imageUri}, 视频:${videoUri}`)
            movingPhoto.requestContent(imageUri, videoUri).then(() => {
              console.info(`导出动态照片成功：${uri} => ${imageUri}， ${videoUri}}`)
              resolve("success")
            }).catch((err: BusinessError) => {
              console.error(`动态图片保存失败, error code is ${err.code}, message is ${err.message}`);
              reject(err)
            })
          }
        });
      } catch (err) {
        console.error(`failed to request moving photo, error code is ${err.code}, message is ${err.message}`);
        reject(err)
      }
    });
  }


}