import { TaskItem } from "../models/TaskItem";
import { AppStorageV2 } from '@kit.ArkUI';
import { WinBreakpoint } from "../common/WinBreakpoint";
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { TaskItemStatus } from "../typing";
import { IBestLoading } from "@ibestservices/ibest-ui-v2";
import { IBestSkeletonParagraph } from "@ibestservices/ibest-ui-v2";
import { emitter } from "@kit.BasicServicesKit";
import { Global } from "../models/Global";

@ComponentV2
export struct TaskItemComponent {
  @Consumer('pageInfos') pageInfos: NavPathStack = new NavPathStack();
  @Param taskItem: TaskItem | null = null;
  @Param index: number = 0;
  @Local isDelete: boolean = false;
  @Local thumbnail: PixelMap | null = null;
  @Local winBP: WinBreakpoint =
    AppStorageV2.connect(WinBreakpoint, 'windowBreakpoint', () => WinBreakpoint.getInstance())!;
  @Local imageTypeRes: string = "";
  @Local imageStatusIcon: string = "";
  @Local progress: number = 0;
  @Local progressY: number = 100;
  private ctx: Context = getContext(this);
  private statusIcon: Record<number, string> = {
    1: "", // WAIT
    2: "sys.media.ohos_public_ok_filled", // SUCCESS
    3: "sys.media.ohos_ic_public_close", // FAILED
    4: "", // UPLOADING
  }

  private statusIconColor: Record<number, Color> = {
    1: Color.Black, // WAIT
    2: Color.Green, // SUCCESS
    3: Color.Red, // FAILED
  }

  async aboutToAppear() {
    if (this.taskItem === null) {
      return
    }
    this.taskItem.getThumbnail(this.ctx, this.winBP.imageSize).then((pm: PixelMap | null) => {
      if (pm === null) {
        this.isDelete = true;
      } else {
        this.thumbnail = pm;
      }

    }).catch(() => {
      // 无法查询缩略图，图片可能已删除，显示默认
    })
    this.updateIcon();
    if (this.taskItem.status !== TaskItemStatus.SUCCESS) {
      emitter.on(Global.UPDATE_TASK_ITEM_EVENT + '_' + this.taskItem.id, async (data) => {
        if (!this.taskItem) return;
        if (data.data?.action === "START") {
          this.taskItem.status = TaskItemStatus.UPLOADING;
        }
        if (data.data?.action === "SUCCESS") {
          this.taskItem.status = TaskItemStatus.SUCCESS;
          this.progress = 100;
          this.progressY = 0;
        }
        if (data.data?.action === "FAIL") {
          this.taskItem.status = TaskItemStatus.FAIL;
          this.taskItem.failedReason = data.data?.reason;
          this.progress = 0;
          this.progressY = 100;
        }
        if (data.data?.action === "PROGRESS") {
          this.taskItem.uploadedSize = data.data?.uploadedSize;
          this.progress = Math.floor(this.taskItem.uploadedSize / this.taskItem.size * 100);
          this.progressY = 100 - this.progress;
        }
        this.updateIcon();
      })
    }
  }

  updateIcon() {
    if (this.taskItem === null) {
      return
    }
    if (this.taskItem.photoType === photoAccessHelper.PhotoType.IMAGE) {
      if (this.taskItem.subType === photoAccessHelper.PhotoSubtype.MOVING_PHOTO) {
        this.imageTypeRes = "app.media.livephoto"
      } else {
        this.imageTypeRes = "app.media.picture_fill"
      }
    }
    if (this.taskItem.photoType === photoAccessHelper.PhotoType.VIDEO) {
      this.imageTypeRes = "app.media.dot_video_fill"
    }
    this.imageStatusIcon = this.statusIcon[this.taskItem.status];
  }

  build() {
    Stack() {
      if (!this.isDelete) {
        if (this.thumbnail !== null) {
          Image(this.thumbnail).width(this.winBP.imageSize).height(this.winBP.imageSize).objectFit(ImageFit.Cover)
            .geometryTransition(this.taskItem?.id + '')
        } else {
          IBestSkeletonParagraph({type: "image", rowWidth: this.winBP.imageSize, rowHeight: this.winBP.imageSize})
        }
      } else {
        Column() {
          Text("已删除")
        }
        .width(this.winBP.imageSize).height(this.winBP.imageSize)
        .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
      }
      Column() {}
      .width('100%')
      .height(`${this.progress}%`)
      .position({x: 0, y: this.progressY})
      .backgroundColor(Color.Black)
      .opacity(0.5)
      Row() {
        Image($r(this.imageTypeRes)).width(18).height(18)
        if (this.taskItem && this.taskItem.status !== TaskItemStatus.UPLOADING) {
          Image($r(this.imageStatusIcon)).width(18).height(18).fillColor(this.statusIconColor[this.taskItem.status])
        } else {
          IBestLoading({ loadingSize: 18 })
        }
      }
      .width('100%')
      .height(28)
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.SpaceBetween)
      .position({x: 2, y: 0})
    }
    .width(this.winBP.imageSize).height(this.winBP.imageSize)
    .onClick(() => {
      animateTo({
        duration: 350,
        curve: Curve.Friction
      }, () => {
        this.pageInfos.pushPathByName("taskItemDetail", this.taskItem?.id);
      })

    })
  }
}