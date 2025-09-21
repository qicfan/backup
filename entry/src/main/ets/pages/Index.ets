import { IBestNotify } from "@ibestservices/ibest-ui-v2";
import { ServerConfig } from "../models/Server";
import { AppStorageV2, ComponentContent, LevelMode, promptAction } from "@kit.ArkUI";
import { Global } from "../models/Global";
import {
  ConfigGlobalStatus,
  LoginStatus,
} from "../typing";
import { Config } from "../models/Config";
import { Login } from "../components/Login";
import { Privacy } from "../components/Privacy";
import { TipDialog } from "../dialogs/TipDialog";
import { Agreement } from "../components/Agreement";
import { Home } from "../components/Home";
import { BackGroundUtil } from "../utils/BackgroundUtil";
import { TaskItemDetail } from "../components/TaskItemDetail";
import { BackupServer } from "../utils/server";
import { ServerPhotoItemDetail } from "../components/ServerPhotoItemDetail";
import { TaskUpload } from "../utils/taskUpload";
import { common } from "@kit.AbilityKit";

@Builder
function buildTip(params: TipDialogParams) {
  TipDialog({close: params.event, pageInfos: params.pageInfos})
}

class TipDialogParams {
  event: (init: boolean) => void = () => {}
  pageInfos: NavPathStack = new NavPathStack();

  constructor(event: (init: boolean) => void, pageInfos: NavPathStack) {
    this.event = event;
    this.pageInfos = pageInfos;
  }
}

@Entry
@ComponentV2
struct Index {
  @Local server: ServerConfig = AppStorageV2.connect(ServerConfig, "server", () => ServerConfig.getInstance())!;
  @Local config: Config = AppStorageV2.connect(Config, "config", () => Config.getInstance())!;
  @Local backupServer: BackupServer = AppStorageV2.connect(BackupServer, "BackupServer", () => BackupServer.getInstance())!;
  @Local global: Global = AppStorageV2.connect(Global, "global", () => Global.getInstance())!;
  @Provider('pageInfos') pageInfos: NavPathStack = new NavPathStack();
  @Local creatingTask: boolean = false;
  @Local init: number = 0;

  ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

  private uiContext: UIContext = this.getUIContext();
  private contentNode = new ComponentContent(this.getUIContext(), wrapBuilder(buildTip), new TipDialogParams(() => {this.closeDialog()},  this.pageInfos));

  private openTipDialog() {
    const node: FrameNode | null = this.getUIContext().getFrameNodeById("home") || null;
    const options: promptAction.BaseDialogOptions = {
      alignment: DialogAlignment.BottomStart,
      transition: TransitionEffect.move(TransitionEdge.BOTTOM).animation({ duration: 500, curve: Curve.Ease }),
      autoCancel: false,
      levelMode: LevelMode.EMBEDDED,
      levelUniqueId: node?.getUniqueId(),
      onWillDismiss: ()=>{
        return false;
      }
    };
    this.uiContext.getPromptAction().openCustomDialog(this.contentNode, options).catch(() => {
      console.warn("打开使用须知弹窗失败")
    });
  }

  private closeDialog() {
    this.uiContext.getPromptAction().closeCustomDialog(this.contentNode).catch(() => {
      console.warn("关闭使用须知弹窗失败")
    });
    this.initApp().then();
  }

  aboutToAppear() {
  }

  onPageShow(): void {
    // 从后台转入前台时触发生成新任务
    console.log('进入首页')
    this.initApp().then((rs) => {
      if (!rs) return ;
      let ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      console.log(`开始创建任务`);
      (TaskUpload.getInstance()).startCreateTask(ctx).then()
    })
  }

  onPageHide(): void {
    console.log('app切换到后台或者离开首页');
    if (this.global.processId > 0) {
      console.log(`index 触发 后台任务`);
      (BackGroundUtil.getInstance()).startBackground(this.ctx);
    } else {
      console.log(`index 未触发 后台任务, ${this.global.processId}, ${canIUse("SystemCapability.ResourceSchedule.BackgroundTaskManager.ContinuousTask")}`);
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
      } else {
        return false;
      }
      return true
    } else {
      return false;
    }
  }

  // 检查是否第一次打开，如果是则弹出提示窗口
  async checkFirst(): Promise<boolean> {
    console.log('check 是否同意协议')
    if (this.config.first === 0) {
      this.openTipDialog();
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
      console.warn('找不到服务器设置，重新登录')
      this.init = 1;
      return false;
    }
    this.global.loginStatus = LoginStatus.NO_LOGIN;
    // 检查服务器是否可用
    this.backupServer.updateConfig(this.server, this.config);
    const rs = await this.backupServer.valid();
    if (!rs) {
      this.init = 1;
      // 登录失败，重新登录
      console.warn('登录失败，重新登录')
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
      if (this.global.toSetting) {
        this.global.tabIndex = 2;
      }
      return false;
    }
    if (configExists === 2) {
      // 没有设置备份目录，提示并跳转
      // IBestNotify.show({
      //   message: "您还没有设置备份路径"
      // })
      if (this.global.toSetting) {
        this.global.tabIndex = 2;
      }
      this.init = 2;
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
    } else if (name == "serverItemDetail") {
      ServerPhotoItemDetail()
    }
  }

  build() {
    Navigation(this.pageInfos) {
      Home()
        .id("home")
    }
    .navDestination(this.PageMap)
    .mode(NavigationMode.Stack)
    .hideToolBar(true)
    .hideTitleBar(true)
    .hideBackButton(true)
    .width('100%')
    .height('100%')
    .onNavBarStateChange((isVisible: boolean) => {
      if (!isVisible) {
        this.uiContext.getPromptAction().closeCustomDialog(this.contentNode).catch(() => {
          console.warn("关闭使用说明弹窗出错")
        });
        return;
      } else {
        this.initApp().then(() => {});
      }
    })
  }
}