import { IBestNavBar, IBestButton } from "@ibestservices/ibest-ui-v2";

@Entry
@Component
struct Index {

  @Builder
  rightBuilder() {
    Image($r("app.media.gearshape"))
      .width(24)
      .height(24)
      .fillColor('#000')
  }

  build() {
    Column(){
      IBestNavBar({
        title: "相册备份",
        isShowLeft: false,
        isShowRight: true,
        rightIcon: "app.media.gearshape",
        rightLabel: "设置",
        onRightClick: () => {
          // 弹出设置窗口
        }
      })
      Column() {
        Text("主体区域")
      }
        .layoutWeight(1)
        .padding(10)
      Column() {
        IBestButton({
          text: '开始备份',
          type: 'primary'
        })
      }
        .width('100%')
        .padding({right: 10})
        .alignItems(HorizontalAlign.End)
    }
      .width('100%')
      .height('100%')
  }
}