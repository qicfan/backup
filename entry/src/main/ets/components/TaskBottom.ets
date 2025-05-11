import { IBestIcon, IBestLoading, IBestNotify, IBestProgress, IBestToast } from "@ibestservices/ibest-ui-v2";
import { AppStorageV2 } from "@kit.ArkUI";
import { Global } from "../models/Global";
import { pointer } from "@kit.InputKit";
import { emitter } from "@kit.BasicServicesKit";
import { TaskItemDataSource } from "../models/TaskItemDataSource";
import { LowBatteryStop, OnlyWIFIBackup } from "../typing";
import { Config } from "../models/Config";
import { getBatteryLevel, getCurrentNetType } from "../utils/tools";
import { connection } from "@kit.NetworkKit";
import { TaskUpload } from "../utils/taskUpload";
import { common } from "@kit.AbilityKit";
import { TaskItem } from "../models/TaskItem";

@ComponentV2
export struct TaskBottom {
  @Local total: number = 0;
  @Local progress: number = 0;
  @Local doing: boolean = false;
  @Local global: Global = AppStorageV2.connect(Global, "global", () => Global.getInstance())!;
  @Local config: Config = AppStorageV2.connect(Config, "config", () => Config.getInstance())!;
  @Consumer("taskItemDataSource") data: TaskItemDataSource = new TaskItemDataSource();
  private siHandle: number = 0;
  private ctxUIAbility: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    this.total = TaskItem.getWaitCount();
  }

  checkBattery() {
    if (this.config.lowBatteryStop === LowBatteryStop.YES) {
      if (getBatteryLevel() <= 15) {
        IBestNotify.show({
          message: "已打开低电量不备份，当前电量低于15%，不启动备份任务",
          type: "warning",
          duration: 3000
        })
        return false;
      }
    }
    return true;
  }

  async checkWifi() {
    if (this.config.onlyWifi === OnlyWIFIBackup.YES) {
      const netType = await getCurrentNetType();
      if (netType == connection.NetBearType.BEARER_CELLULAR) {
        IBestNotify.show({
          message: "已打开仅wifi备份，当前使用移动网络，不启动备份任务",
          type: "warning",
          duration: 3000
        })
        return false;
      }
    }
    return true;
  }
  // 是否开源启动任务执行
  async canStart(): Promise<boolean> {
    // 如果打开了低电量暂停任务，则检查电量
    if (!this.checkBattery()) {
      console.error(`电量不足15%，无法执行任务`);
      return false;
    }
    // 如果打开了仅WIFI备份，则检查网络状态
    if (!(await this.checkWifi())) {
      console.error(`非WIFI，无法执行任务`);
      return false;
    }
    if (!this.config.backupRootPath) {
      IBestToast.show({
        message: "请先设置备份路径",
        type: "warning",
        duration: 3000
      })
      return false;
    }
    return true;
  }

  async startTask() {
    if (this.doing) {
      // 已经启动了
      return ;
    }
    if (!(await this.canStart())) {
      return false;
    }
    this.global.processId = 1;
    this.doing = true;
    this.global.preTotal = this.total;
    this.siHandle = setInterval(() => {
      // 每隔0.3秒检查进度
      this.total  = TaskItem.getWaitCount();
      this.progress = Math.floor(100 - (this.total / this.global.preTotal * 100))
      console.log(`start: 检查进度: ${this.progress}`)
    }, 300);
    emitter.on(Global.BACKUP_TASK_FINISH, () => {
      console.log(`Task Bottom 监听到任务结束`)
      this.doing = false;
      this.global.processId = 0;
      clearInterval(this.siHandle);
      this.siHandle = 0;
    });
    (TaskUpload.getInstance()).start(this.ctxUIAbility);
    console.log("发送开始任务通知")
    emitter.emit(Global.START_WAIT_TASK_EVENT);
    return true;
  }

  stopTask() {
    console.log("发送暂停任务通知：")
    this.doing = false;
    this.global.processId = 0;
    clearInterval(this.siHandle);
    this.siHandle = 0;
    emitter.emit(Global.STOP_TASK_EVENT);
    emitter.emit(Global.BACKUP_PAUSE);
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
            if (this.doing) {
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
          if (this.doing) {
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
          if (this.doing) {
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
    .backgroundColor($r('app.color.ibest_white'))
    .width('100%')
    .padding($r("app.float.normal_padding"))
  }
}