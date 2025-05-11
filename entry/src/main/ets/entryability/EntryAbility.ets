import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStorageV2, display, window } from '@kit.ArkUI';
import { IBestInit } from "@ibestservices/ibest-ui-v2";
import { DB } from '../models/DB';
import { SafeArea } from '../utils/safeArea';
import { rpc } from '@kit.IPCKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { BreakpointConstants } from '../common/BreakpointConstants';
import { WinBreakpoint } from '../common/WinBreakpoint';
import { WindowUtil } from '../utils/windowUtil';

const DOMAIN = 0x0000;
const TAG: string = 'WidgetEventCallEntryAbility';
const DOMAIN_NUMBER: number = 0xFF00;
const CONST_NUMBER_1: number = 1;

// rpc通信返回类型的实现，用于rpc通信数据序列化和反序列化
class MyParcelable implements rpc.Parcelable {
  num: number;
  str: string;

  constructor(num: number, str: string) {
    this.num = num;
    this.str = str;
  }

  marshalling(messageSequence: rpc.MessageSequence): boolean {
    messageSequence.writeInt(this.num);
    messageSequence.writeString(this.str);
    return true;
  }

  unmarshalling(messageSequence: rpc.MessageSequence): boolean {
    this.num = messageSequence.readInt();
    this.str = messageSequence.readString();
    return true;
  }
}

export default class EntryAbility extends UIAbility {
  private windowObj?: window.Window;

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

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    // checkPermissions(this.context, 'ohos.permission.READ_IMAGEVIDEO'); // 申请权限
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    AppStorageV2.connect(WinBreakpoint, 'windowBreakpoint', () => WinBreakpoint.getInstance());
    try {
      // 监听call事件所需的方法并调用
      this.callee.on('backup', (data: rpc.MessageSequence) => {
        // 获取call事件中传递的所有参数
        hilog.info(DOMAIN_NUMBER, TAG, `backup param:  ${JSON.stringify(data.readString())}`);
        return new MyParcelable(CONST_NUMBER_1, 'aaa');
      });
    } catch (err) {
      hilog.error(DOMAIN_NUMBER, TAG, `Failed to register callee on. Cause: ${JSON.stringify(err as BusinessError)}`);
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
    try {
      this.callee.off('backup');
    } catch (err) {
      hilog.error(DOMAIN_NUMBER, TAG, `Failed to register callee off. Cause: ${JSON.stringify(err as BusinessError)}`);
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
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
    try {
      this.callee.off('funA');
    } catch (err) {
      hilog.error(DOMAIN_NUMBER, TAG, `Failed to register callee off. Cause: ${JSON.stringify(err as BusinessError)}`);
    }
  }

  onForeground(): void {
    // Ability has brought to foreground
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