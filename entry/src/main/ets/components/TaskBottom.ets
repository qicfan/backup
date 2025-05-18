import { IBestIcon, IBestLoading, IBestProgress } from "@ibestservices/ibest-ui-v2";
import { AppStorageV2 } from "@kit.ArkUI";
import { Global } from "../models/Global";
import { pointer } from "@kit.InputKit";
import { emitter } from "@kit.BasicServicesKit";
import { WaitTaskItemDataSource } from "../models/TaskItemDataSource";
import { Config } from "../models/Config";
import { TaskUpload } from "../utils/taskUpload";
import { TaskItem } from "../models/TaskItem";

@ComponentV2
export struct TaskBottom {
  @Local total: number = 0;
  @Local progress: number = 0;
  @Local global: Global = AppStorageV2.connect(Global, "global", () => Global.getInstance())!;
  @Local config: Config = AppStorageV2.connect(Config, "config", () => Config.getInstance())!;

  private handleId: number|null = null;

  aboutToAppear(): void {
    this.total = TaskItem.getWaitCount();
  }

  async startTask() {
    (TaskUpload.getInstance()).start(this.total);
    // 定时更新进度
    this.handleId = setInterval(() => {
      this.updateProgress();
    }, 1000);
    emitter.once(Global.BACKUP_TASK_FINISH, () => {
      this.updateProgress();
      if (this.handleId) {
        clearInterval(this.handleId);
        this.handleId = null;
      }
    })
    emitter.once(Global.STOP_TASK_EVENT, () => {
      this.updateProgress();
      if (this.handleId) {
        clearInterval(this.handleId);
        this.handleId = null;
      }
    });
    return true;
  }

  stopTask() {
    (TaskUpload.getInstance()).stop();
    if (this.handleId) {
      clearInterval(this.handleId);
      this.handleId = null;
    }
  }

  updateProgress() {
    TaskItem.getUploadingResultCount().then((c: number) => {
      this.total = c;
      this.progress = Math.floor(100 - (this.total / this.global.preTotal * 100));
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
        Column() {
          Flex({
            direction: FlexDirection.Row,
            wrap: FlexWrap.NoWrap,
            justifyContent: FlexAlign.Start,
            alignItems: ItemAlign.Center
          }) {
            if (this.global.processId > 0) {
              IBestLoading({ loadingSize: 18 })
                .margin({right: $r("app.float.normal_padding")})
            }
            Text(`待备份: ${this.total}张`)
              .margin({ right: $r('app.float.inner_padding') })
          }
          .width('100%')
          Column() {
            IBestProgress({
              value: this.progress
            })
              .width('100%')
              .padding({ left: $r("app.float.normal_padding") })
          }
        }
        .layoutWeight(1)

        Column() {
          if (this.global.processId > 0) {
            IBestIcon({ name: "pause-circle-o", iconSize: 24 })
          } else {
            IBestIcon({ name: "play-circle-o", iconSize: 24, color: Color.Blue })
          }
        }
        .width(24)
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .margin({ left: $r('app.float.inner_padding') })
        .onHover((flag) => {
          if (flag) {
            this.getUIContext().getCursorController().setCursor(pointer.PointerStyle.HAND_GRABBING)
          } else {
            this.getUIContext().getCursorController().restoreDefault()
          }
        })
        .onClick(() => {
          if (this.total <= 0) return;
          if (this.global.processId > 0) {
            this.stopTask();
          } else {
            this.startTask();
          }
          return;
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
    .backgroundColor($r('app.color.ibest_background'))
    .width('100%')
    .padding($r("app.float.normal_padding"))
  }
}