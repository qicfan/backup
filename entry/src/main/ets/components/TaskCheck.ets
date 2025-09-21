import { IBestButton } from "@ibestservices/ibest-ui-v2"
import { Global } from "../models/Global";
import { AppStorageV2 } from "@kit.ArkUI";

import { TaskDoing } from "../typing";

import { Config } from "../models/Config";
import { TaskUpload } from "../utils/taskUpload";
import { common } from "@kit.AbilityKit";

@ComponentV2
export struct TaskCheck {
  @Local config: Config = AppStorageV2.connect(Config, "config", () => Config.getInstance())!;
  @Local global: Global = AppStorageV2.connect(Global, "global", () => Global.getInstance())!;
  @Local loadingText: string = "正在收集需要备份的项目..."

  ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

  aboutToAppear(): void {
  }

  build() {
    Column() {
      IBestButton({
        text: '开始备份',
        type: this.global.taskGlobalStatus === TaskDoing.YES ? 'default' : 'primary',
        loadingText: this.loadingText + ', 已收集：' + this.global.idx,
        loading: this.global.taskGlobalStatus == TaskDoing.YES,
        onBtnClick: () => {
          (TaskUpload.getInstance()).startCreateTask(this.ctx).then(() => {})
        }
      })
    }
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.ibest_background'))
    .width('100%')
    .padding($r("app.float.normal_padding"))
  }
}