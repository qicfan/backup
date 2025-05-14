import { TaskItem } from "../models/TaskItem";
import { AppStorageV2, FoldSplitContainer } from "@kit.ArkUI";
import { IBestSkeletonParagraph } from "@ibestservices/ibest-ui-v2";
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { formatFileSize, strip } from "../utils/tools";
import { TaskItemStatus } from "../typing";
import { dateTimeFromTimestamp } from "../utils/date";
import { Config } from "../models/Config";
import { ServerConfig } from "../models/Server";

@ComponentV2
export struct TaskItemDetail {
  @Consumer('pageInfos') pageInfos: NavPathStack = new NavPathStack();
  @Local config: Config = AppStorageV2.connect(Config, "config", () => Config.getInstance())!;
  @Local server: ServerConfig = AppStorageV2.connect(ServerConfig, "server", () => ServerConfig.getInstance())!;
  @Local taskItem: TaskItem = new TaskItem();
  @Local init: boolean = false;
  @Local thumbnail: PixelMap | null = null;
  private taskItemId: number | undefined = undefined;
  private controller: VideoController = new VideoController();
  private statusName: Record<number, string> = {
    1: "等待备份",
    2: "已备份",
    3: "备份失败",
    4: "备份中...",
  }

  @Computed
  get remoteUri(): string {
    let uri: string = this.server.server;
    if (uri.endsWith('/')) {
      uri = strip(uri, '/');
    }
    if (!this.config.backupRootPath.startsWith('/')) {
      uri += '/' + this.config.backupRootPath;
    } else {
      uri += this.config.backupRootPath;
    }
    if (uri.endsWith('/')) {
      uri = strip(uri, '/');
    }
    if (!this.taskItem.remoteUri.startsWith('/')) {
      uri += '/' + this.taskItem.remoteUri;
    } else {
      uri += this.taskItem.remoteUri;
    }
    return uri;
  }

  @Builder
  privateRegion() {
    if (!this.init) {
      IBestSkeletonParagraph({type: "image", rowWidth: '50%', rowHeight: '80%'})
    } else {
      if (this.taskItem === undefined) {
        Text("该照片已删除，无法预览")
          .backgroundColor('rgba(0, 255, 0, 0.1)')
          .fontSize(28)
          .textAlign(TextAlign.Center)
          .height('100%')
          .width('100%')
      } else {
        if (this.taskItem.photoType === photoAccessHelper.PhotoType.IMAGE) {
          // 图片，显示缩略图
          Image(this.thumbnail).height('100%').width('100%').objectFit(ImageFit.Contain)
            .geometryTransition(this.taskItem?.id + '');
        } else {
          // 视频
          Video({
            src: this.taskItem.uri,
            previewUri: this.thumbnail,
            controller: this.controller
          })
        }
      }
    }

  }

  @Builder
  secondaryRegion() {
    Column() {
      Row() {
        Text("状态: ").width(80)
        Text(this.statusName[this.taskItem.status]).layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .margin({bottom: $r("app.float.inner_padding")})
      Row() {
        Text('文件名: ').width(80)
        Text(this.taskItem.name).layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .margin({bottom: $r("app.float.inner_padding")})
      Row() {
        Text('文件大小: ').width(80)
        Text(formatFileSize(this.taskItem.size)).layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .margin({bottom: $r("app.float.inner_padding")})
      if (this.taskItem.status === TaskItemStatus.SUCCESS) {
        Row() {
          Text('上传时间: ').width(80)
          Text(dateTimeFromTimestamp(this.taskItem.uploadedAt)).layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .margin({bottom: $r("app.float.inner_padding")})
        Row() {
          Text('远程地址: ').width(80)
          Text(this.remoteUri).layoutWeight(1).copyOption(CopyOptions.LocalDevice)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .margin({bottom: $r("app.float.inner_padding")})
      }
      if (this.taskItem.status === TaskItemStatus.FAIL) {
        Row() {
          Text('失败原因: ').width(80)
          Text(this.taskItem.failedReason).layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
    }
    .padding($r('app.float.normal_padding'))
  }

  build() {
    NavDestination() {
      RelativeContainer() {
        FoldSplitContainer({
          primary: () => {
            this.privateRegion()
          },
          secondary: () => {
            this.secondaryRegion()
          },
        })
      }
      .height('100%')
      .width('100%')
    }
    .title("照片详情")
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.ibest_background'))
    .onShown(() => {
      console.log('照片详情显示')
      this.taskItemId = this.pageInfos.getParamByIndex(0) as number;
      TaskItem.getById(this.taskItemId).then((taskItem: TaskItem | undefined) => {
        if (taskItem === undefined) {
          this.init = true;
          return ;
        }
        this.taskItem = taskItem;
        if (this.taskItem) {
          this.taskItem.getThumbnail(getContext(this), 800).then((pm: PixelMap | null) => {
            if (pm !== null) {
              this.thumbnail = pm;
            }
            this.init = true;
          }).catch(() => {
            // 无法查询缩略图，图片可能已删除，显示默认
            this.init = true;
          })
        }
      })
      console.log(`详情页ID： ${this.taskItemId}`)
    })
  }
}