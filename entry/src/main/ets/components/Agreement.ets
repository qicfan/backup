import { webview } from "@kit.ArkWeb"

@ComponentV2
export struct Agreement {
  controller: WebviewController = new webview.WebviewController();
  @Consumer('pageInfos') pageInfos: NavPathStack = new NavPathStack()

  build() {
    NavDestination() {
      Column() {
        Web({src: $rawfile('index.html'), controller: this.controller})
      }
      .width('100%')
      .height('100%')
    }
    .title("用户协议")
    .width('100%')
    .backgroundColor($r('app.color.ibest_background'))
  }
}