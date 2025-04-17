import { webview } from "@kit.ArkWeb"

@ComponentV2
export struct PrivacyComponent {
  controller: WebviewController = new webview.WebviewController();
  @Consumer('pageInfos') pageInfos: NavPathStack = new NavPathStack()

  aboutToAppear(): void {
    console.log('隐私协议加载')
  }
  aboutToDisappear(): void {
    console.log('隐私协议销毁')
  }
  build() {
    NavDestination() {
      Column() {
        Web({src: "https://agreement-drcn.hispace.dbankcloud.cn/index.html?lang=zh&agreementId=1664801032779082240", controller: this.controller})
      }
      .width('100%')
      .height('100%')
    }
    .title("隐私协议")
    .width('100%')
    .backgroundColor($r('app.color.ibest_background'))
  }
}