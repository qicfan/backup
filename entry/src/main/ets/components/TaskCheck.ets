import { IBestButton } from "@ibestservices/ibest-ui-v2"
import { Global } from "../models/Global";
import { AppStorageV2 } from "@kit.ArkUI";

import { TaskDoing } from "../typing";

import { Config } from "../models/Config";
import { TaskUpload } from "../utils/taskUpload";

@ComponentV2
export struct TaskCheck {
  @Local config: Config = AppStorageV2.connect(Config, "config", () => Config.getInstance())!;
  @Local global: Global = AppStorageV2.connect(Global, "global", () => Global.getInstance())!;
  @Local loadingText: string = "正在收集需要备份的项目..."

  aboutToAppear(): void {}

  build() {
    Column() {
      IBestButton({
        text: '开始备份',
        type: this.global.taskGlobalStatus === TaskDoing.YES ? 'default' : 'primary',
        loadingText: this.loadingText,
        loading: this.global.taskGlobalStatus == TaskDoing.YES
      })
        .onClick(() => {
          (TaskUpload.getInstance()).startCreateTask(getContext(this)).then(() => {})
        })
    }
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.ibest_background'))
    .width('100%')
    .padding($r("app.float.normal_padding"))
  }
}