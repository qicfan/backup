import { webview } from "@kit.ArkWeb"

@ComponentV2
export struct Privacy {
  controller: WebviewController = new webview.WebviewController();
  @Consumer('pageInfos') pageInfos: NavPathStack = new NavPathStack()

  build() {
    NavDestination() {
      Column() {
        Web({
          src: "https://agreement-drcn.hispace.dbankcloud.cn/index.html?lang=zh&agreementId=1668279675706681856",
          controller: this.controller
        })
      }
      .width('100%')
      .height('100%')
    }
    .title("隐私协议")
    .width('100%')
    .backgroundColor($r('app.color.ibest_background'))
  }
}