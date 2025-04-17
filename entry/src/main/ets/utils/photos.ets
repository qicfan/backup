import { PhotoItem, TaskItemStatus } from "../typing";
import { dataSharePredicates } from "@kit.ArkData";
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { TaskItem } from "../models/TaskItem";

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
      console.log("Photos 查询到 " + fetchRs.getCount() + " 条数据")
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
        item.uri = ps.uri;
        item.photoType = ps.photoType as number;
        item.subType = ps.get('subtype') as number;
        item.name = ps.displayName;
        item.dateAdded = ps.get('date_added') as number;
        item.dateModified = ps.get('date_modified') as number;
        item.size = ps.get('size') as number;
        item.status = TaskItemStatus.WAIT;
        item.makeRemoteUri()
        item.makeFileUri(ctx)
        if (item.dateAdded < lastTimestamp) {
          continue;
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

  // 将动态图片的图片和视频保存到本地沙箱文件
  static async saveMovingPhoto(ctx: Context, uri: string, imageUri: string, videoUri: string): Promise<boolean> {
    return new Promise(async (resolve, reject) => {
      let predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
      predicates.equalTo(photoAccessHelper.PhotoKeys.PHOTO_SUBTYPE, photoAccessHelper.PhotoSubtype.MOVING_PHOTO).and().equalTo('uri', uri);
      let fetchOptions: photoAccessHelper.FetchOptions = {
        fetchColumns: [],
        predicates: predicates
      };
      let phAccessHelper = photoAccessHelper.getPhotoAccessHelper(ctx);
      let assetResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> = await phAccessHelper.getAssets(fetchOptions);
      let asset: photoAccessHelper.PhotoAsset = await assetResult.getFirstObject();
      let requestOptions: photoAccessHelper.RequestOptions = {
        deliveryMode: photoAccessHelper.DeliveryMode.HIGH_QUALITY_MODE,
      }

      try {
        let requestId: string = await photoAccessHelper.MediaAssetManager.requestMovingPhoto(ctx, asset, requestOptions, {
          onDataPrepared: (movingPhoto: photoAccessHelper.MovingPhoto) => {
            if (movingPhoto === undefined) {
              console.error('Error occurred when preparing data');
              resolve(false)
              return;
            }
            console.info("moving photo acquired successfully, uri: " + movingPhoto.getUri());
            console.info(`读取动态图片${uri}，图片：${movingPhoto.getUri()}=>${imageUri}, 视频:${videoUri}`)
            movingPhoto.requestContent(imageUri, videoUri).then(() => {
              resolve(true)
            }).catch((err: BusinessError) => {
              console.error(`动态图片保存失败, error code is ${err.code}, message is ${err.message}`);
              reject(err)
            })
          }
        });
        console.info("moving photo requested successfully, requestId: " + requestId);
      } catch (err) {
        console.error(`failed to request moving photo, error code is ${err.code}, message is ${err.message}`);
        reject(err)
      }
    });
  }
}