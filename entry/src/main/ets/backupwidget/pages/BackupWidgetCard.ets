@Entry
@Component
struct BackupWidgetCard {

  @LocalStorageProp('formId') formId: string = '';
  /*
   * The title.
   */
  readonly startTitle: string = '开始备份';
  readonly stopTitle: string = '停止备份';
  /*
   * The action type.
   */
  readonly actionType: string = 'call';
  /*
   * The ability name.
   */
  readonly abilityName: string = 'EntryAbility';
  /*
   * The width percentage setting.
   */
  readonly fullWidthPercent: string = '100%';
  /*
   * The height percentage setting.
   */
  readonly fullHeightPercent: string = '100%';

  aboutToAppear(): void {
    console.log(this.formId);
  }

  build() {
    Column() {
      Row() {
        Image($r("sys.media.ohos_ic_public_play"))
          .height(24)
          .width(24)
          .margin({ right: $r('app.float.inner_padding') })
        Text(this.startTitle)
          .fontSize($r('app.float.font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
      }
      .height(this.fullHeightPercent)
      .width(this.fullWidthPercent)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        postCardAction(this, {
          action: this.actionType,
          abilityName: this.abilityName,
          params: {
            formId: this.formId,
            // 需要调用的方法名称
            method: 'backup'
          }
        });
      })
    }
  }
}