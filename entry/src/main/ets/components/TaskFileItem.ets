import { IBestDialogUtil, IBestIcon, IBestImagePreview, IBestLoading, IBestNotify } from "@ibestservices/ibest-ui-v2";
import { TaskItem } from "../models/TaskItem";
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { Photos } from "../utils/photos";
import { BusinessError, emitter } from "@kit.BasicServicesKit";
import { formatFileSize } from "../utils/tools";
import { TaskItemStatus } from "../typing";
import { AppStorageV2 } from "@kit.ArkUI";
import { Config } from "../models/Config";
import { WebDav } from "../utils/webdav";
import { Global } from "../models/Global";

@ComponentV2
export struct TaskFileItem {
  @Param fileItem: TaskItem = new TaskItem();
  @Local config: Config = AppStorageV2.connect(Config, "config", () => new Config())!;
  @Local webdav: WebDav = AppStorageV2.connect(WebDav, "webdav", () => new WebDav())!;
  @Local thumbnail: PixelMap | undefined = undefined;
  private asset: photoAccessHelper.PhotoAsset | undefined = undefined;
  private bigPhotoPm: PixelMap | undefined = undefined;

  aboutToAppear(): void {
    this.fileItem.updateWebDav(this.webdav, this.config);
    this.getData().then()
  }

  async getData() {
    try {
      // 查询asset，显示缩略图
      this.asset = await Photos.getPhotoAssetByUri(getContext(this), this.fileItem.uri);
      if (this.asset) {
        this.thumbnail = await this.asset.getThumbnail({ height: 128, width: 128 })
      }
    } catch (e) {
      let err = e as BusinessError;
      console.log(`查询asset失败,code:${err.code}, msg:${err.message}`);
    }
  }

  async previewPhoto() {
    if (!this.bigPhotoPm) {
      // 查询大图的pixelMap
      this.bigPhotoPm = await Photos.getPixelMapByAsset(getContext(this), this.asset);
      if (!this.bigPhotoPm) {
        IBestNotify.show({
          message: "图片不存在，无法查看大图",
          type: "warning",
          duration: 3000
        })
        return false;
      }
    }

    IBestImagePreview.show([this.bigPhotoPm], {
      indexPosition: 'top'
    })
    return true;
  }

  @Computed
  get fileSize() {
    return formatFileSize(this.fileItem.size);
  }

  reUpload() {
    IBestDialogUtil.open({
      title: "提示",
      message: "请确认是否重新上传该图片？",
      showCancelButton: true,
      onConfirm: async () => {
        const rs = await this.fileItem.upload(getContext(this));
        if (rs) {
          await this.fileItem.task.updateSuccess(1);
          await this.fileItem.task.updateFailed(-1);
          emitter.emit(Global.UPDATE_TASK_EVENT, { data: { id: this.fileItem.taskId } })
        }
      }
    })
  }

  build() {
    Column() {
      Flex({
        direction: FlexDirection.Row,
        wrap: FlexWrap.NoWrap,
        justifyContent: FlexAlign.SpaceBetween,
        alignItems: ItemAlign.Center
      }) {
        Image(this.thumbnail)
          .width(64)
          .margin({right: $r('app.float.inner_padding')})
          .onClick(() => {
            this.previewPhoto();
          })
        Column() {
          Flex({
            direction: FlexDirection.Column,
            wrap: FlexWrap.NoWrap,
          }) {
            Text("失败原因: " + this.fileItem.failedReason)
              .textAlign(TextAlign.Start)
              .fontSize($r('sys.float.ohos_id_tip_font_size'))
            Column() {
              Text(`大小: ${this.fileSize}`)
                .fontSize($r('sys.float.ohos_id_tip_font_size'))
            }
            .margin({top: $r('app.float.inner_padding')})
          }
          .width('100%')

        }
        .layoutWeight(1)

        Column() {
          if (this.fileItem.status === TaskItemStatus.UPLOADING) {
            IBestLoading({ loadingSize: 18 })
          } else {
            IBestIcon({ name: "upgrade", iconSize: 24, color: Color.Blue })
              .onClick(() => {
                this.reUpload();
              })
          }

        }
        .width(24)
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .margin({ left: $r('app.float.inner_padding') })
        .onClick(() => {

        })
      }
      .padding($r('app.float.normal_padding'))
      .backgroundColor($r("app.color.ibest_search_inner_background"))
      .borderRadius(10)
      .shadow({
        radius: 8,
        color: Color.Gray,
        offsetX: 10,
        offsetY: 10
      })
    }
    .margin({ bottom: $r("app.float.normal_padding") })
    .backgroundColor($r('app.color.ibest_background'))
    .width('100%')
    .padding({left: $r("app.float.normal_padding"), right: $r("app.float.normal_padding")})
  }
}