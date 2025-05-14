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
import { Privacy } from "../components/Privacy";
import { TipDialog } from "../dialogs/TipDialog";
import { Dialog } from "../utils/dialog";
import { Agreement } from "../components/Agreement";
import { Home } from "../components/Home";
import { TaskUpload } from "../utils/taskUpload";
import { BackGroundUtil } from "../utils/BackgroundUtil";
import { TaskItemDetail } from "../components/TaskItemDetail";

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
  @Provider('pageInfos') pageInfos: NavPathStack = new NavPathStack()
  @Local creatingTask: boolean = false;
  @Local init: number = 0;

  private openTipDialog() {
    Dialog.setContext(this.getUIContext());
    Dialog.setContentNode(new ComponentContent(this.getUIContext(), wrapBuilder(buildTip), () => {this.closeDialog()}));
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
  }

  onPageShow(): void {
    // 从后台转入前台时触发生成新任务
    console.log('进入首页')
    setTimeout(() => {
      (TaskUpload.getInstance()).startCreateTask(getContext(this)).then()
    }, 3000);
  }

  onPageHide(): void {
    console.log('app切换到后台或者离开首页');
    if (canIUse("SystemCapability.ResourceSchedule.BackgroundTaskManager.ContinuousTask") && this.global.processId > 0) {
      console.log(`index 触发 后台任务`);
      (BackGroundUtil.getInstance()).startBackground();
    } else {
      console.log(`index 触发 后台任务失败, ${this.global.processId}, ${canIUse("SystemCapability.ResourceSchedule.BackgroundTaskManager.ContinuousTask")}`);
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

  @Builder
  PageMap(name: string) {
    if (name === "login") {
      Login()
    } else if (name === "PrivacyComponent") {
      Privacy()
    } else if(name == "agreement") {
      Agreement()
    } else if (name == "taskItemDetail") {
      TaskItemDetail()
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