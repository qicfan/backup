import { common, WantAgent, wantAgent } from "@kit.AbilityKit";
import { backgroundTaskManager } from "@kit.BackgroundTasksKit";
import { Global } from "../models/Global";
import { BusinessError, emitter } from "@kit.BasicServicesKit";
import { TaskItem } from "../models/TaskItem";
import { notificationManager } from "@kit.NotificationKit";

export class BackGroundUtil {
  ctxUIAbility: common.UIAbilityContext = getContext() as common.UIAbilityContext;
  global: Global = Global.getInstance();
  private static _instance: BackGroundUtil | null = null;
  private notifyId: number = 0;
  private jobId: number = 0;

  static getInstance() {
    if (BackGroundUtil._instance === null) {
      BackGroundUtil._instance = new BackGroundUtil();
    }
    return BackGroundUtil._instance;
  }

  // 停止任务
  async stopBackground() {
    // 触发任务暂停
    // emitter.emit(Global.STOP_TASK_EVENT);
    this.notifyId = 0;
    this.jobId = 0;
    if (canIUse("SystemCapability.ResourceSchedule.BackgroundTaskManager.ContinuousTask") && this.jobId > 0) {
      // 取消长时任务
      backgroundTaskManager.stopBackgroundRunning(this.ctxUIAbility);
    }
  }

  // 启动长时任务
  async startBackground() {
    console.log(`应用退后台，启动后台任务1`)
    if (!canIUse("SystemCapability.ResourceSchedule.BackgroundTaskManager.ContinuousTask") || this.jobId > 0) {
      return "不支持后台任务或者有运行中的任务";
    }
    console.log(`应用退后台，启动后台任务2`)
    // 暂停任务-
    emitter.once(Global.STOP_BACKGROUND_EVENT, () => this.stopBackground());
    const wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [{ bundleName: this.ctxUIAbility.abilityInfo.bundleName, abilityName: this.ctxUIAbility.abilityInfo.name }],
      actionType: wantAgent.OperationType.START_ABILITY, requestCode: 0,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    // 监听停止长时任务
    backgroundTaskManager.on("continuousTaskCancel", (info: backgroundTaskManager.ContinuousTaskCancelInfo) => {
      // 标记任务状态，然后停止上传
      console.log(`收到取消长时任务的通知，停止执行当前任务，信息：${JSON.stringify(info)}`);
      console.log(`当前执行的长时任务ID：${this.notifyId}，要取消的长时任务ID${info.id}`)
      this.stopBackground();
    });
    wantAgent.getWantAgent(wantAgentInfo).then((wantAgentObj: WantAgent) => {
      backgroundTaskManager.startBackgroundRunning(this.ctxUIAbility, ["dataTransfer"], wantAgentObj)
        .then((res: backgroundTaskManager.ContinuousTaskNotification) => {
          this.notifyId = res.notificationId;
          this.jobId = res.continuousTaskId ? res.continuousTaskId : 1;
          const updateProgressHandleId = setInterval(() => {
            if (this.notifyId <= 0) {
              console.log("任务已结束，清除定时通知系统任务进度");
              clearInterval(updateProgressHandleId);
              return;
            }
            // 每秒更新一次任务进度
            this.updateNotifyProcess().then(() => {});
          }, 1000);
        })
        .catch((error: BusinessError) => {
          console.error(`启动长时任务失败. code is ${error.code} message is ${error.message}`);
        });
    }).catch((error: BusinessError) => {
      console.error(`Operation getWantAgent failed. code is ${error.code} message is ${error.message}`);
    });
    return "";
  }

  // 应用更新通知栏进度
  async updateNotifyProcess() {
    // 应用定义下载类通知模版
    const total = await TaskItem.getUploadingResultCount();
    const cur = this.global.preTotal - total;
    const progress = Math.floor(100 - (total / this.global.preTotal * 100))
    let downLoadTemplate: notificationManager.NotificationTemplate = {
      name: 'downloadTemplate', // 当前只支持downloadTemplate，保持不变
      data: {
        title: `正在备份照片`, // 必填。
        fileName: `进度：${cur}/${this.global.preTotal}`, // 必填。
        progressValue: progress, // 应用更新进度值，自定义。
      }
    };
    let request: notificationManager.NotificationRequest = {
      content: {
        // 系统实况类型，保持不变
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_SYSTEM_LIVE_VIEW,
        systemLiveView: {
          typeCode: 8, // 上传下载类型需要填写 8，当前仅支持此类型。保持不变
          title: "正在备份照片", // 应用自定义
          text: `进度：${cur}/${this.global.preTotal}`, // 应用自定义
          capsule: {
            title: `备份进度：${cur}/${this.global.preTotal}`
          }
        }
      },
      id: this.notifyId, // 必须是申请长时任务返回的id，否则应用更新通知失败。
      notificationSlotType: notificationManager.SlotType.LIVE_VIEW, // 实况窗类型，保持不变
      template: downLoadTemplate // 应用需要设置的模版名称
    };
    notificationManager.publish(request).then(() => {
    }).catch((err: BusinessError) => {
      console.error(`更新长时任务进度失败: code: ${err.code}. msg: ${err.message}`);
    });
  }
}