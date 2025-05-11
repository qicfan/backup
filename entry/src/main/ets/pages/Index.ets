import { IBestNotify } from "@ibestservices/ibest-ui-v2";
import { ServerConfig } from "../models/Server";
import { AppStorageV2, ComponentContent } from "@kit.ArkUI";
import { common, WantAgent, wantAgent } from "@kit.AbilityKit";
import { Global } from "../models/Global";
import {
  ConfigGlobalStatus,
  LoginStatus,
} from "../typing";
import { Config } from "../models/Config";
import { Login } from "../components/Login";
import { WebDav } from "../utils/webdav";
import { BusinessError, emitter } from "@kit.BasicServicesKit";
import { backgroundTaskManager } from "@kit.BackgroundTasksKit";
import { notificationManager } from "@kit.NotificationKit";
import { Privacy } from "../components/Privacy";
import { TipDialog } from "../dialogs/TipDialog";
import { Dialog } from "../utils/dialog";
import { Agreement } from "../components/Agreement";
import { Home } from "../components/Home";
import { TaskItem } from "../models/TaskItem";

@Builder
function buildTip(event: ()=>void) {
  TipDialog({close: event})
}

@Entry
@ComponentV2
struct Index {
  @Local server: ServerConfig = AppStorageV2.connect(ServerConfig, "server", () => ServerConfig.getInstance())!;
  @Local config: Config = AppStorageV2.connect(Config, "config", () => Config.getInstance())!;
  @Local webdav: WebDav = AppStorageV2.connect(WebDav, "webdav", () => WebDav.getInstance())!;
  @Local global: Global = AppStorageV2.connect(Global, "global", () => Global.getInstance())!;
  private ctxUIAbility: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  @Provider('pageInfos') pageInfos: NavPathStack = new NavPathStack()
  @Local creatingTask: boolean = false;

  private notifyId: number = 0;
  private jobId: number = 0;
  private init: number = 0; // 0-未开始, 1-未设置服务器, 2-未完善色湖之，3-初始化成功

  // 登录弹窗的节点
  private tipDialogContentNode: ComponentContent<Object> =
    new ComponentContent(this.getUIContext(), wrapBuilder(buildTip), () => {this.closeDialog()})

  private openTipDialog() {
    Dialog.setContext(this.getUIContext());
    Dialog.setContentNode(this.tipDialogContentNode);
    Dialog.setOptions({
      alignment: DialogAlignment.BottomStart,
      isModal: true,
      transition: TransitionEffect.move(TransitionEdge.BOTTOM).animation({ duration: 500, curve: Curve.Ease }),
      autoCancel: false,
      onWillDismiss: ()=>{
        return false;
      }
    });
    Dialog.openDialog();
  }

  private closeDialog() {
    Dialog.closeDialog();
    this.initApp().then();
  }

  aboutToAppear() {
    this.initApp().then(() => {});
    // 暂停任务
    emitter.on(Global.STOP_TASK_EVENT, () => {
      console.log("收到暂停任务通知")
      this.stopTaskEvent()
    })
  }

  async aboutToDisappear() {
    if (this.global.processId > 0) {
      // 有正在运行的任务，结束任务
      await this.stopTaskEvent()
    }
  }

  onPageShow(): void {
    // 从后台转入前台时触发生成新任务
    console.log('进入首页')
    setTimeout(() => {
      emitter.emit(Global.START_COLLECT_PHOTO_EVENT);
    }, 3000);

  }

  onPageHide(): void {
    console.log('app切换到后台或者离开首页');
    if (canIUse("SystemCapability.ResourceSchedule.BackgroundTaskManager.ContinuousTask") && this.global.processId > 0) {
      this.startBackground();
    }
  }

  // app启动时进行各项功能初始化和检测
  async initApp() {
    let r1: boolean, r2: boolean = false;
    await this.config.init();
    r1 = await this.checkFirst();
    if (r1) {
      r2 = await this.checkServer();
      if (r2) {
        await this.checkConfig();
      }
    }
    return true;
  }

  // 检查是否第一次打开，如果是则弹出提示窗口
  async checkFirst(): Promise<boolean> {
    console.log(this.config.first + ', 是否首次打开')
    if (this.config.first === 0) {
      this.openTipDialog();
      console.log('显示首次弹窗')
      return false;
    }
    return true;
  }

  // 检查是否有服务器，没有则跳转到服务器添加页面
  // 如果有则检查连通性，不可用则跳转到服务器添加页面
  async checkServer(): Promise<boolean> {
    const serverExists = await this.server.queryAsset();
    if (!serverExists) {
      // 没有服务器配置
      this.init = 1;
      this.pageInfos.pushPath({ name: "login" })
      return false;
    }
    this.global.loginStatus = LoginStatus.NO_LOGIN;
    // 检查服务器是否可用
    this.webdav.updateSerConfig(this.server);
    const rs = await this.webdav.valid();
    if (!rs) {
      this.init = 1;
      // 登录失败，重新登录
      this.pageInfos.pushPath({ name: "login" });
      return false;
    }
    this.global.loginStatus = LoginStatus.LOGIN;
    return true;
  }

  // 检查配置是否完整，不完整则跳转到设置页面
  async checkConfig(): Promise<boolean> {
    const configExists = await this.config.init();
    if (configExists === 0) {
      // 不存在设置，跳转到设置页面
      this.init = 2;
      // this.pageInfos.pushPath({ name: "Settings" })
      this.global.tabIndex = 2;
      return false;
    }
    if (configExists === 2) {
      // 没有设置备份目录，提示并跳转
      IBestNotify.show({
        message: "您还没有设置备份路径"
      })
      this.init = 2;
      this.global.tabIndex = 2;
      return false;
    }
    this.global.configGlobalStatus = ConfigGlobalStatus.YES
    this.init = 3;
    return true;
  }

  // 停止任务
  async stopTaskEvent() {
    await this.stopTask();
  }

  // 停止任务
  async stopTask() {
    this.notifyId = 0;
    this.jobId = 0;
    this.global.processId = 0;
    if (canIUse("SystemCapability.ResourceSchedule.BackgroundTaskManager.ContinuousTask") && this.jobId > 0) {
      // 取消长时任务
      backgroundTaskManager.stopBackgroundRunning(this.ctxUIAbility);
    }
  }

  // 启动长时任务
  async startBackground() {
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
      this.stopTaskEvent();
    });
    wantAgent.getWantAgent(wantAgentInfo).then((wantAgentObj: WantAgent) => {
      backgroundTaskManager.startBackgroundRunning(this.ctxUIAbility, ["dataTransfer"], wantAgentObj)
        .then((res: backgroundTaskManager.ContinuousTaskNotification) => {
          this.notifyId = res.notificationId;
          this.jobId = res.continuousTaskId ? res.continuousTaskId : 1;
          const updateProgressHandleId = setInterval(() => {
            if (this.notifyId <= 0) {
              console.log("任务已结束，清除定时通知系统任务进度")
              clearInterval(updateProgressHandleId);
              return;
            }
            // 每秒更新一次任务进度
            this.updateNotifyProcess();
          }, 1000);
        })
        .catch((error: BusinessError) => {
          console.error(`启动长时任务失败. code is ${error.code} message is ${error.message}`);
        });
    }).catch((error: BusinessError) => {
      console.error(`Operation getWantAgent failed. code is ${error.code} message is ${error.message}`);
    });
  }

  // 应用更新通知栏进度
  updateNotifyProcess() {
    // 应用定义下载类通知模版
    const total = TaskItem.getWaitCount();
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

  @Builder
  PageMap(name: string) {
    if (name === "login") {
      Login()
    } else if (name === "PrivacyComponent") {
      Privacy()
    } else if(name == "agreement") {
      Agreement()
    }
  }

  build() {
    Navigation(this.pageInfos) {
      Home()
    }
    .navDestination(this.PageMap)
    .mode(NavigationMode.Stack)
    .hideToolBar(true)
    .hideTitleBar(true)
    .hideBackButton(true)
    .width('100%')
    .height('100%')
  }
}