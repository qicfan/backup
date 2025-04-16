import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStorageV2, window } from '@kit.ArkUI';
import { IBestInit } from "@ibestservices/ibest-ui-v2";
import { DB } from '../models/DB';
import { SafeArea } from '../utils/safeArea';
import { checkPermissions } from '../utils/permission';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    checkPermissions(this.context, 'ohos.permission.READ_IMAGEVIDEO'); // 申请权限
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
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
        AppStorageV2.connect(SafeArea, () => new SafeArea(topRectHeight, bottomRectHeight))
        windowClass.on('avoidAreaChange', (data) => {
          if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
            let topRectHeight = data.area.topRect.height;
          } else if (data.type == window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
            let bottomRectHeight = data.area.bottomRect.height;
            AppStorageV2.connect(SafeArea, () => new SafeArea(topRectHeight, bottomRectHeight))
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