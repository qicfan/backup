import { PhotoItem, TaskItemStatus } from "../typing";
import { dataSharePredicates } from "@kit.ArkData";
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { TaskItem } from "../models/TaskItem";
import { image } from "@kit.ImageKit";
import { fileSize } from "./tools";

export class Photos {
  /**
   * 查询未备份的照片列表
   * @param number lastTimestamp 最后一次备份的时间戳，只取添加时间大于等于该指的照片
   */
  static async getPhotos(ctx: Context, lastTimestamp: number, page: number = 1,
    pageSize: number = 100): Promise<TaskItem[]> {
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
    try {
      while (!fetchRs.isAfterLast()) {
        let ps: photoAccessHelper.PhotoAsset;
        ps = await fetchRs.getNextObject()
        const item = new TaskItem()
        item.dateAdded = ps.get('date_added') as number;
        if (item.dateAdded < lastTimestamp) {
          continue;
        }
        item.uri = ps.uri;
        item.photoType = ps.photoType as number;
        item.subType = ps.get('subtype') as number;
        item.name = ps.displayName;
        item.dateModified = ps.get('date_modified') as number;
        item.size = ps.get('size') as number;
        item.status = TaskItemStatus.WAIT;
        item.makeUri(ctx)
        // 处理动态图片
        if (item.subType == photoAccessHelper.PhotoSubtype.MOVING_PHOTO) {
          // 保存动态图片的视频
          const videoSize = await Photos.saveMovingPhotoVideoByAsset(ctx, ps, item.videoUri);
          if (videoSize === -1) {
            continue;
          }
          item.videoSize = videoSize;
        } else {
          item.videoSize = 0;
        }
        items.push(item)
      }
    } catch (e) {
      let err = e as BusinessError;
      console.log(`获取photo assets失败，code=${err.code}, msg=${err.message}`)
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
            console.info(`读取动态图片${asset.get('uri')}的视频，视频本地路径:${videoUri}`)
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
      }

      try {
        let requestId: string = await photoAccessHelper.MediaAssetManager.requestMovingPhoto(ctx, asset, requestOptions, {
          onDataPrepared: (movingPhoto: photoAccessHelper.MovingPhoto) => {
            if (movingPhoto === undefined) {
              resolve("读取动态图片数据出错，请检查该图片是否存在或重试")
            }
            console.info(`读取动态图片${uri}，图片：${movingPhoto.getUri()}=>${imageUri}, 视频:${videoUri}`)
            movingPhoto.requestContent(imageUri, videoUri).then(() => {
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