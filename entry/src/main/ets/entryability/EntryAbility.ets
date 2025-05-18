import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStorageV2, display, window } from '@kit.ArkUI';
import { IBestInit } from "@ibestservices/ibest-ui-v2";
import { DB } from '../models/DB';
import { SafeArea } from '../utils/safeArea';
import { rpc } from '@kit.IPCKit';
import { BusinessError, emitter } from '@kit.BasicServicesKit';
import { BreakpointConstants } from '../common/BreakpointConstants';
import { WinBreakpoint } from '../common/WinBreakpoint';
import { WindowUtil } from '../utils/windowUtil';
import { ConfigGlobalStatus, FormStatus, LoginStatus } from '../typing';
import { formBindingData, formProvider } from '@kit.FormKit';
import { TaskUpload } from '../utils/taskUpload';
import { TaskItem } from '../models/TaskItem';
import { Global } from '../models/Global';
import { BackGroundUtil } from '../utils/BackgroundUtil';
import { ServerConfig } from '../models/Server';
import { Config } from '../models/Config';

const DOMAIN = 0x0000;
const TAG: string = 'WidgetEventCallEntryAbility';
const DOMAIN_NUMBER: number = 0xFF00;

// rpc通信返回类型的实现，用于rpc通信数据序列化和反序列化
class MyParcelable implements rpc.Parcelable {
  status: FormStatus;
  preTotal: number;
  total: number;

  constructor(status: FormStatus, preTotal: number, total: number) {
    this.status = status;
    this.preTotal = preTotal;
    this.total = total;
  }

  marshalling(messageSequence: rpc.MessageSequence): boolean {
    messageSequence.writeInt(this.status);
    messageSequence.writeInt(this.preTotal);
    messageSequence.writeInt(this.total);
    return true;
  }

  unmarshalling(messageSequence: rpc.MessageSequence): boolean {
    this.status = messageSequence.readInt();
    this.preTotal = messageSequence.readInt();
    this.total = messageSequence.readInt();
    return true;
  }
}

export default class EntryAbility extends UIAbility {
  private windowObj?: window.Window;
  private formId: string = "";

  private updateHeightBp(): void {
    if (this.windowObj === undefined) {
      return;
    }
    let mainWindow: window.WindowProperties = this.windowObj.getWindowProperties();
    let windowHeight: number = mainWindow.windowRect.height;
    let windowWidth: number = mainWindow.windowRect.width;
    let windowWidthVp = windowWidth / display.getDefaultDisplaySync().densityPixels;
    let windowHeightVp = windowHeight / display.getDefaultDisplaySync().densityPixels;
    let heightBp: string = BreakpointConstants.BREAKPOINT_SM;
    let aspectRatio: number = windowHeightVp / windowWidthVp;
    if (aspectRatio < 0.8) {
      heightBp = BreakpointConstants.BREAKPOINT_SM;
    } else if (aspectRatio >= 0.8 && aspectRatio < 1.2) {
      heightBp = BreakpointConstants.BREAKPOINT_MD;
    } else {
      heightBp = BreakpointConstants.BREAKPOINT_LG;
    }
    const winBP = AppStorageV2.connect(WinBreakpoint, 'windowBreakpoint', () => WinBreakpoint.getInstance());
    winBP!.currentHeightBreakpoint = heightBp;
    winBP!.width = windowWidthVp;
    winBP!.height = windowHeightVp;
    winBP!.updateImageSize();
  }

  private updateWidthBp(): void {
    if (this.windowObj === undefined) {
      return;
    }
    let mainWindow: window.WindowProperties = this.windowObj.getWindowProperties();
    let windowWidth: number = mainWindow.windowRect.width;
    let windowWidthVp = windowWidth / display.getDefaultDisplaySync().densityPixels;
    let widthBp: string = BreakpointConstants.BREAKPOINT_XS;
    if (windowWidthVp < 320) {
      widthBp = BreakpointConstants.BREAKPOINT_XS;
    } else if (windowWidthVp >= 320 && windowWidthVp < 600) {
      widthBp = BreakpointConstants.BREAKPOINT_SM;
    } else if (windowWidthVp >= 600 && windowWidthVp < 840) {
      widthBp = BreakpointConstants.BREAKPOINT_MD;
    } else if (windowWidthVp >= 840 && windowWidthVp < 1440) {
      widthBp = BreakpointConstants.BREAKPOINT_LG;
    } else {
      widthBp = BreakpointConstants.BREAKPOINT_XL;
    }
    let winBP = AppStorageV2.connect(WinBreakpoint, 'windowBreakpoint', () => WinBreakpoint.getInstance());
    winBP!.currentWidthBreakpoint = widthBp;
    winBP!.width = windowWidthVp;
    winBP!.updateImageSize();
  }

  notifyFormCollect() {
    let obj: Record<string, string | number> = {
      'formId': this.formId,
      'status': FormStatus.COLLECT,
      'preTotal': 0,
      'total': 0
    };
    let formData: formBindingData.FormBindingData = formBindingData.createFormBindingData(obj);
    formProvider.updateForm(this.formId, formData);
  }
  notifyFormDefault() {
    let obj: Record<string, string | number> = {
      'formId': this.formId,
      'status': FormStatus.DEFAULT,
      'preTotal': 0,
      'total': 0
    };
    let formData: formBindingData.FormBindingData = formBindingData.createFormBindingData(obj);
    formProvider.updateForm(this.formId, formData);
  }
  notifyFormUploadProgress(preTotal: number, total: number) {
    let obj: Record<string, string | number> = {
      'formId': this.formId,
      'status': FormStatus.COLLECT,
      'preTotal': preTotal,
      'total': total
    };
    let formData: formBindingData.FormBindingData = formBindingData.createFormBindingData(obj);
    formProvider.updateForm(this.formId, formData);
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    // hilog.info(DOMAIN_NUMBER, TAG, `want:  ${JSON.stringify(want)}`);
    AppStorageV2.connect(WinBreakpoint, 'windowBreakpoint', () => WinBreakpoint.getInstance());
    emitter.once(Global.EXIT_EVENT, () => {
      this.context.terminateSelf().then(() => {})
    })
    // try {
    //   if (want.parameters === undefined) {
    //     return ;
    //   }
    //   this.formId = want.parameters.formID + '';
    //   // 监听call事件所需的方法并调用
    //   this.callee.on('backup', () => {
    //     hilog.info(DOMAIN_NUMBER, TAG, `卡片执行备份事件，卡片ID:  ${this.formId}`);
    //     const global = Global.getInstance();
    //     const taskUpload = TaskUpload.getInstance();
    //     DB.init(this.context).then(() => {
    //       try {
    //         ServerConfig.getInstance().queryAsset().then((serverRs: boolean) => {
    //           if (!serverRs) return ;
    //           global.loginStatus = LoginStatus.LOGIN;
    //           Config.getInstance().init().then((configRs: number) => {
    //             if (configRs !== 1) return;
    //             global.configGlobalStatus = ConfigGlobalStatus.YES;
    //             // 1. 检索新项目
    //             taskUpload.startCreateTask(this.context).then((exists) => {
    //               hilog.info(DOMAIN_NUMBER, TAG, `是否存在新项目：${exists}`)
    //               this.notifyFormCollect();
    //               // 查询总数
    //               global.preTotal = TaskItem.getWaitCount();
    //               // 2. 触发上传
    //               taskUpload.start().then(() => {
    //                 const total: number = TaskItem.getWaitCount();
    //                 this.notifyFormUploadProgress(global.preTotal, total);
    //                 BackGroundUtil.getInstance().startBackground().then(() => {
    //                   hilog.info(DOMAIN_NUMBER, TAG, `已启动后台任务`)
    //                 })
    //               }).catch((err: BusinessError) => {
    //                 hilog.error(DOMAIN_NUMBER, TAG, `执行任务失败. Cause: ${JSON.stringify(err as BusinessError)}`);
    //               })
    //               // 3. 监听上传事件，通知卡片刷新
    //               // 上传完成的消息，检测任务是否已经完成
    //               emitter.on(Global.BACKUP_UPLOAD_WORKER_IDLE, async () => {
    //                 const total: number = TaskItem.getWaitCount();
    //                 this.notifyFormUploadProgress(global.preTotal, total);
    //               })
    //               emitter.on(Global.BACKUP_TASK_FINISH, () => {
    //                 this.notifyFormDefault();
    //               })
    //             }).catch((err: BusinessError) => {
    //               hilog.error(DOMAIN_NUMBER, TAG, `执行任务失败. Cause: ${JSON.stringify(err as BusinessError)}`);
    //             })
    //           })
    //         })
    //
    //       } catch (err) {
    //         hilog.error(DOMAIN_NUMBER, TAG, `Failed to register callee on. Cause: ${JSON.stringify(err as BusinessError)}`);
    //         this.notifyFormDefault();
    //       }
    //     });
    //     return new MyParcelable(FormStatus.DEFAULT, 0, 0);
    //   });
    // } catch (err) {
    //   hilog.error(DOMAIN_NUMBER, TAG, `Failed to register callee on. Cause: ${JSON.stringify(err as BusinessError)}`);
    //   this.notifyFormDefault();
    // }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
    try {
      this.callee.off('backup');
      this.notifyFormDefault();
    } catch (err) {
      hilog.error(DOMAIN_NUMBER, TAG, `Failed to register callee off. Cause: ${JSON.stringify(err as BusinessError)}`);
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    console.log('载入UI：' + this.formId);
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    windowStage.getMainWindow().then((data: window.Window) => {
      this.windowObj = data;
      this.updateWidthBp();
      this.updateHeightBp();
      this.windowObj.on('windowSizeChange', (windowSize: window.Size) => {
        this.updateWidthBp();
        this.updateHeightBp();
      })
    })
    let windowUtil: WindowUtil | undefined = WindowUtil.getInstance();
    if (windowUtil !== undefined) {
      windowUtil.setWindowStage(windowStage);
      windowUtil.setMainWindowPortrait();
    }
    // 初始化数据库
    DB.init(this.context).then(() => {
      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
        // 初始化UI控件
        IBestInit(windowStage, this.context)
        let windowClass: window.Window = windowStage.getMainWindowSync(); // 获取应用主窗口
        // 2. 获取布局避让遮挡的区域
        let type = window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR; // 以导航条避让为例
        let avoidArea = windowClass.getWindowAvoidArea(type);
        let bottomRectHeight = avoidArea.bottomRect.height; // 获取到导航条区域的高度
        type = window.AvoidAreaType.TYPE_SYSTEM; // 以状态栏避让为例
        avoidArea = windowClass.getWindowAvoidArea(type);
        let topRectHeight = avoidArea.topRect.height; // 获取状态栏区域高度
        const safeArea = AppStorageV2.connect(SafeArea, () => SafeArea.getInstance())!
        safeArea.top = topRectHeight;
        safeArea.bottom = bottomRectHeight;
        windowClass.on('avoidAreaChange', (data) => {
          if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
            let topRectHeight = data.area.topRect.height;
            safeArea.top = topRectHeight;
          } else if (data.type == window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
            let bottomRectHeight = data.area.bottomRect.height;
            safeArea.bottom = bottomRectHeight;
          }
        });
      });
    })
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    console.log('app拉到前台：' + this.formId);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam) {
    // 更新资源、数据
  }
}