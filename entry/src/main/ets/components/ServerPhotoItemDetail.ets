import { AppStorageV2 } from "@kit.ArkUI";
import { IBestNotify, IBestSkeletonParagraph } from "@ibestservices/ibest-ui-v2";
import { Config } from "../models/Config";
import { ServerConfig } from "../models/Server";
import { BackupServer, download, ServerPhotoItem } from "../utils/server";
import { image } from "@kit.ImageKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { common } from "@kit.AbilityKit";
import { MovingPhotoView, MovingPhotoViewController, photoAccessHelper } from "@kit.MediaLibraryKit";
import { taskpool } from "@kit.ArkTS";
import { deleteFile, splitFileExt } from "../utils/tools";
import { Photos } from "../utils/photos";
import { fileIo } from "@kit.CoreFileKit";

@ComponentV2
export struct ServerPhotoItemDetail {
  @Consumer('pageInfos') pageInfos: NavPathStack = new NavPathStack();
  @Local config: Config = AppStorageV2.connect(Config, "config", () => Config.getInstance())!;
  @Local server: ServerConfig = AppStorageV2.connect(ServerConfig, "server", () => ServerConfig.getInstance())!;
  @Local backupServer: BackupServer = AppStorageV2.connect(BackupServer, "BackupServer", () => BackupServer.getInstance())!;
  @Local serverPhotoItem: ServerPhotoItem | undefined = undefined;
  @Local init: boolean = false;
  @Local thumbnail: PixelMap | undefined = undefined;
  @Local fileUri: string = ""
  private is: image.ImageSource | undefined
  private vcontroller: VideoController = new VideoController();
  private controller: MovingPhotoViewController = new MovingPhotoViewController();
  @Local mp: photoAccessHelper.MovingPhoto | undefined = undefined
  @Local loading: boolean = false
  @Local progress: number = 0
  aboutToAppear(): void {
  }

  async getMovingPhoto() {
    if (this.fileUri === "" || this.serverPhotoItem === undefined) {
      return
    }
    // 获取动态照片的asset
    let context: Context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    let photoAsset = await Photos.getPhotoAssetByUri(context, this.fileUri)
    if (photoAsset === undefined) {
      return
    }
    this.mp = await Photos.getMovingPhoto(context, photoAsset)
    console.log(`获取动态照片成功，${this.mp}`)
  }

  async initPage() {
    if (this.serverPhotoItem == undefined) {
      return
    }
    let ctx = getContext(this)
    this.serverPhotoItem.thumbnail =
      await this.backupServer.getThumbnailUrl(ctx, this.serverPhotoItem.path, '768x768')
    // 将图片转成PixelMap
    // console.log('下载缩略图完成，缩略图：' + this.serverPhotoItem.thumbnail)
    // 获取缩略图路径
    let i = 0
    let si = setInterval(() =>{
      if (this.serverPhotoItem === undefined) {
        clearInterval(si)
        return
      }
      try {
        this.is = image.createImageSource(this.serverPhotoItem.thumbnail)
        // console.log('根据路径生成ImageSource成功: ' + this.serverPhotoItem.thumbnail)
      } catch (e) {
        console.error(`根据路径生成imageSource出错:${this.serverPhotoItem.thumbnail}, 错误:${e.message}`)
      }
      i++
      if (this.is !== undefined) {
          this.is?.createPixelMap().then((pm: PixelMap) => {
            this.thumbnail = pm
            this.is?.release()
            this.init = true
            // console.log(`根据imageSource生产PixelMap成功：${this.serverPhotoItem?.thumbnail} => ${this.thumbnail}`)
            this.fileUri = this.serverPhotoItem ? this.serverPhotoItem.fileUri : ""
            if (this.serverPhotoItem?.type === 3) {
              this.getMovingPhoto()
            }
            clearInterval(si)
          }).catch((e: BusinessError) => {
            console.error(`根据imageSource生成PixelMap出错:${this.serverPhotoItem?.thumbnail}, 错误:${e.message}`)
          })
      }
      if (i > 10) {
        console.error(`重试 ${i} 次后依然无法生成imageSource，跳出循环`)
        clearInterval(si)
        return
      }
    }, 100)
  }

  build() {
    NavDestination() {
      Column() {
        Column() {
          if (!this.init) {
            IBestSkeletonParagraph({ type: "image", rowWidth: '100%', rowHeight: '100%' })
          } else {
            if (this.loading) {
              // 显示下载进度
              Column() {
                Progress({value: this.progress, total: 100, type: ProgressType.Ring})
                  .color('rgba(0, 85, 255, 1)')
                  .style({ strokeWidth: 4, shadow: true})
                  .height(48)
              }
              .width('100%')
              .height('100%')
              .alignItems(HorizontalAlign.Center)
              .justifyContent(FlexAlign.Center)
            } else {
              if (this.fileUri == "" || (this.fileUri !== "" && this.serverPhotoItem?.type == 1)) {
                // 普通照片
                Image(this.thumbnail)
                  .width('100%')
                  .objectFit(ImageFit.Contain)
              }
              if (this.fileUri !== "" && this.serverPhotoItem?.type == 2) {
                // 视频
                Video({
                  src: this.serverPhotoItem.fileUri,
                  previewUri: this.thumbnail,
                  controller: this.vcontroller
                })
              }
              if (this.fileUri !== "" && this.serverPhotoItem?.type == 3 && this.mp !== undefined) {
                // 动态照片
                MovingPhotoView({ movingPhoto: this.mp, controller: this.controller })
              }
            }
          }
        }
        .width('100%%')
        .layoutWeight(1)
        .margin({bottom: $r("app.float.normal_padding")})
        Column() {
          if (this.fileUri == "") {
            SaveButton({
              icon: SaveIconStyle.FULL_FILLED,
              buttonType: ButtonType.Circle
            })
              .height(28)
              .width(28)
              .onClick(async (event, result: SaveButtonOnClickResult) => {
                if (result != SaveButtonOnClickResult.SUCCESS) {
                  console.error('SaveButtonOnClickResult create asset failed');
                  return false;
                }
                if (!this.serverPhotoItem || this.loading) {
                  return false;
                }
                this.loading = true
                console.log(`保存照片：${this.serverPhotoItem.path}, 照片类型：${this.serverPhotoItem.type}`)

                let context: Context = this.getUIContext().getHostContext() as common.UIAbilityContext;
                let imageOrVideoDestFile = context.tempDir + '/' + this.serverPhotoItem.path
                let ext = splitFileExt(this.serverPhotoItem.name)[0]
                let transcode = false
                if (ext.toLowerCase() == 'heic') {
                  imageOrVideoDestFile += '.jpg'
                  transcode = true
                }
                let videoDestFile: string = ""
                let success = false
                try {
                  // 下载资源到本地路径
                  success = await taskpool.execute(download, this.serverPhotoItem.path, imageOrVideoDestFile,
                    this.serverPhotoItem.type == 3, transcode, ".jpg", ".mp4",
                    this.backupServer.getToken(), this.server.server, this.config.backupRootPath
                  ) as boolean;
                } catch (err) {
                  console.error(`download failed with error: ${err.code}, ${err.message}`);
                  this.loading = false
                  return false
                }
                if (!success) {
                  IBestNotify.show({
                    message: "下载源文件失败",
                    duration: 3000,
                    type: 'warning'
                  });
                  this.loading = false
                  return false
                }
                if (this.serverPhotoItem.type === 3) {
                  // 动态照片，继续下载视频
                  videoDestFile = context.tempDir + '/' + this.serverPhotoItem.live_photo_video_path
                  let ext = splitFileExt(videoDestFile)[0]
                  if (ext.toLowerCase() == 'mov') {
                    transcode = true
                    videoDestFile += '.mp4'
                  }
                  const success1 = await taskpool.execute(download, this.serverPhotoItem.live_photo_video_path,
                    videoDestFile, true, transcode, ".jpg", ".mp4",
                    this.backupServer.getToken(), this.server.server, this.config.backupRootPath
                  );
                  if (!success1) {
                    IBestNotify.show({
                      message: "下载动态照片的视频源文件失败",
                      duration: 3000,
                      type: 'warning'
                    });
                    this.loading = false
                    return false
                  }
                }

                try {
                  let asset: photoAccessHelper.PhotoAsset
                  // 保存到图库
                  let phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
                  if (this.serverPhotoItem.type !== 3) {
                    let assetChangeRequest: photoAccessHelper.MediaAssetChangeRequest =
                      photoAccessHelper.MediaAssetChangeRequest.createImageAssetRequest(context, imageOrVideoDestFile);
                    assetChangeRequest.setTitle(this.serverPhotoItem.name)
                    await phAccessHelper.applyChanges(assetChangeRequest);
                    asset = assetChangeRequest.getAsset()
                    // 保存uri到服务器
                    console.info('createAsset successfully, uri: ' + asset.uri);
                    // 清除临时文件
                    deleteFile(imageOrVideoDestFile)
                    this.serverPhotoItem.fileUri = asset.uri
                  } else {
                    let assetChangeRequest: photoAccessHelper.MediaAssetChangeRequest = photoAccessHelper.MediaAssetChangeRequest.createAssetRequest(context, photoAccessHelper.PhotoType.IMAGE, "jpg", {
                      // title: this.serverPhotoItem.name,
                      subtype: photoAccessHelper.PhotoSubtype.MOVING_PHOTO
                    });
                    assetChangeRequest.addResource(photoAccessHelper.ResourceType.IMAGE_RESOURCE, imageOrVideoDestFile);
                    assetChangeRequest.addResource(photoAccessHelper.ResourceType.VIDEO_RESOURCE, videoDestFile);
                    // assetChangeRequest.setTitle(this.serverPhotoItem.name + '.jpg')
                    await phAccessHelper.applyChanges(assetChangeRequest);
                    asset = assetChangeRequest.getAsset()

                    console.info('create moving photo successfully, uri: ' + asset.uri);
                    // 清除临时文件
                    deleteFile(imageOrVideoDestFile)
                    deleteFile(videoDestFile)
                    this.serverPhotoItem.fileUri = asset.uri
                    this.mp = await Photos.getMovingPhoto(context, asset)
                  }

                  // 保存fileUri到服务器
                  await this.backupServer.photoUpdate(this.serverPhotoItem.path, asset.uri)
                  this.fileUri = asset.uri
                  this.loading = false
                  return true

                } catch (err) {
                  console.error(`create asset2 failed with error: ${err.code}, ${err.message}`);
                  this.loading = false
                  return false
                }
              })
          }
        }
        .width('100%')
        .height(40)
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
    }
    .title("照片详情")
    .width('100%')
    .height('100%')
    // .backgroundColor($r('app.color.ibest_black'))
    .onShown(() => {
      console.log('照片详情显示')
      this.serverPhotoItem = this.pageInfos.getParamByIndex(0) as ServerPhotoItem;
      this.initPage()
      console.log(`详情页图片路径： ${this.serverPhotoItem.path}`)
    })
    .onHidden(() => {
      // 释放资源
      if (this.thumbnail !== undefined) this.thumbnail.release()
    })
  }
}