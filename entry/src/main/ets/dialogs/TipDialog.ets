import { IBestButton } from "@ibestservices/ibest-ui-v2";
import { AppStorageV2 } from "@kit.ArkUI";
import { Config } from "../models/Config";
import { Dialog } from "../utils/dialog";
import { SafeArea } from "../utils/safeArea";

@ComponentV2
export struct TipDialog {
  @Event close: ()=>void = () => {}
  @Local safeArea: SafeArea = AppStorageV2.connect(SafeArea, () => SafeArea.getInstance())!;
  @Local config: Config = AppStorageV2.connect(Config, "config", () => Config.getInstance())!;

  build() {
    Column() {
      Text("使用协议")
        .textAlign(TextAlign.Center)
        .fontSize($r('sys.float.ohos_id_picker_title_font_size'))
        .width('100%')
        .margin({ top: $r('app.float.normal_padding'), bottom: $r('app.float.normal_padding') })
      Scroll() {
        Column() {
          Text("1. 请选择新目录保存备份，防止文件被误删除。")
            .width('100%')
            .margin({ bottom: $r('app.float.inner_padding') })
          Text("2. 当服务器上已存在要备份的同名文件时，本应用会根据文件大小来判断文件是否一致，如果不一致则会删除服务器上的同名文件")
            .width('100%')
            .margin({ bottom: $r('app.float.inner_padding') })
          Text("3. 备份时退出本应用，应用会申请类型为'数据传输'的后台任务，后台任务执行时会在通知栏显示进度。")
            .width('100%')
            .margin({ bottom: $r('app.float.inner_padding') })
          Text("4. 后台任务执行可能被系统强行中止，碰到此种情况可打开应用重新开始备份。")
            .width('100%')
            .margin({ bottom: $r('app.float.inner_padding') })
          Text("5. 由于各种限制，本应用不支持文件的断点续传，所以不对备份结果做保证，请谨慎使用。")
            .width('100%')
            .margin({ bottom: $r('app.float.inner_padding') })
          Text("6. 由于本应用备份导致的文件丢失，本应用概不负责。")
            .width('100%')
            .margin({ bottom: $r('app.float.inner_padding') })
          Text("点击屏幕下方'已知晓，开始使用'按钮代表您已知晓并同意上述条款，您稍后可在设置页面查看详细的‘用户协议’。")
            .width('100%')
            .margin({ top: $r('app.float.normal_padding') })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding($r('app.float.normal_padding'))
      }
      .backgroundColor($r('app.color.ibest_white'))
      .width('100%')
      .layoutWeight(1)
      .borderRadius({ topLeft: 12, topRight: 12 })
      .padding({
        left: $r('app.float.normal_padding'),
        right: $r('app.float.normal_padding'),
        top: $r('app.float.normal_padding')
      })

      Column() {
        IBestButton({
          text: "已知晓，开始使用",
          type: "primary",
          btnBorderRadius: 10,
          onBtnClick: () => {
            this.config.first = 1;
            this.config.update().then(() => {
              this.close();
            })
          }
        })
      }
      .margin({ top: $r('app.float.normal_padding') })

    }
    .width('100%')
    .height('80%')
    .borderRadius({ topLeft: 12, topRight: 12 })
    .backgroundColor($r('app.color.ibest_background'))
    .padding({ bottom: px2vp(this.safeArea.bottom) })
  }
}