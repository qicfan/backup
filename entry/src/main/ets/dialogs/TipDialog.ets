import { IBestButton } from "@ibestservices/ibest-ui-v2";
import { AppStorageV2 } from "@kit.ArkUI";
import { Config } from "../models/Config";
import { SafeArea } from "../utils/safeArea";
import { pointer } from "@kit.InputKit";
import { Global } from "../models/Global";
import { emitter } from "@kit.BasicServicesKit";

@ComponentV2
export struct TipDialog {
  @Event close: (init: boolean)=>void = (init: boolean) => {}
  @Local safeArea: SafeArea = AppStorageV2.connect(SafeArea, () => SafeArea.getInstance())!;
  @Local config: Config = AppStorageV2.connect(Config, "config", () => Config.getInstance())!;
  @Param pageInfos: NavPathStack = new NavPathStack();

  build() {
    Column() {
      Text("使用须知")
        .textAlign(TextAlign.Center)
        .fontSize($r('sys.float.ohos_id_picker_title_font_size'))
        .width('100%')
        .margin({ top: $r('app.float.normal_padding'), bottom: $r('app.float.normal_padding') })
      Scroll() {
        Column() {
          Text("1. 备份前请在您的NAS（家庭存储服务器）上安装本应用的服务器端，然后请选择新目录保存备份，防止文件被误删除。")
            .width('100%')
            .margin({ bottom: $r('app.float.inner_padding') })
          Text("2. 当服务器上已存在要备份的同名文件时，本应用会根据文件的SHA1哈希值来判断文件是否一致，如果不一致则会删除服务器上的同名文件")
            .width('100%')
            .margin({ bottom: $r('app.float.inner_padding') })
          Text("3. 备份时本应用退到后台时会申请类型为'数据传输'的后台任务，后台任务执行时会在通知栏显示进度。")
            .width('100%')
            .margin({ bottom: $r('app.float.inner_padding') })
          Text("4. 后台任务执行可能被系统强行中止，碰到此种情况可打开应用重新开始备份。")
            .width('100%')
            .margin({ bottom: $r('app.float.inner_padding') })
          Text("5. 由于本应用备份导致的文件丢失，本应用概不负责，备份完成后请检查文件确实存在于服务器中再删除本机上的源文件")
            .width('100%')
            .margin({ bottom: $r('app.float.inner_padding') })
          Text('点击下方"同意"按钮表示您该须知和下方的协议')
            .width('100%')
          Row() {
            Text("《隐私协议》")
              .margin({ right: $r('app.float.normal_padding') })
              .fontColor(Color.Blue)
              .onClick(() => {
                console.log(`跳转到隐私协议`);
                this.pageInfos.pushPathByName("PrivacyComponent", "");
              })
              .onHover((flag) => {
                if (flag) {
                  this.getUIContext().getCursorController().setCursor(pointer.PointerStyle.HAND_GRABBING)
                } else {
                  this.getUIContext().getCursorController().restoreDefault()
                }
              })
            Text("和")
            Text("《用户协议》")
              .margin({ left: $r('app.float.normal_padding') })
              .fontColor(Color.Blue)
              .onClick(() => {
                console.log(`跳转到用户协议`)
                this.pageInfos.pushPathByName("agreement", "");
              })
              .onHover((flag) => {
                if (flag) {
                  this.getUIContext().getCursorController().setCursor(pointer.PointerStyle.HAND_GRABBING)
                } else {
                  this.getUIContext().getCursorController().restoreDefault()
                }
              })
          }
          .width('100%')
          .margin({ top: $r('app.float.normal_padding') })
        }
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
        .width('100%')
        .height('100%')
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

      Row() {
        IBestButton({
          text: "拒绝",
          type: "default",
          btnBorderRadius: 10,
          onBtnClick: () => {
            emitter.emit(Global.EXIT_EVENT);
          }
        })
          .onHover((flag) => {
            if (flag) {
              this.getUIContext().getCursorController().setCursor(pointer.PointerStyle.HAND_GRABBING)
            } else {
              this.getUIContext().getCursorController().restoreDefault()
            }
          })
        IBestButton({
          text: "同意",
          type: "primary",
          btnBorderRadius: 10,
          onBtnClick: () => {
            this.config.first = 1;
            this.config.update().then(() => {
              this.close(true);
            })
          }
        })
          .onHover((flag) => {
            if (flag) {
              this.getUIContext().getCursorController().setCursor(pointer.PointerStyle.HAND_GRABBING)
            } else {
              this.getUIContext().getCursorController().restoreDefault()
            }
          })
      }
      .width('80%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: $r('app.float.normal_padding') })
    }
    .width('100%')
    .height('80%')
    .borderRadius({ topLeft: 12, topRight: 12 })
    .backgroundColor($r('app.color.ibest_background'))
    .padding({ bottom: px2vp(this.safeArea.bottom) })
    .justifyContent(FlexAlign.Start)
  }
}