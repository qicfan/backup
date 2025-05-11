import { IBestNotify, IBestPicker, IBestPickerOption, IBestPopup } from "@ibestservices/ibest-ui-v2"
import { Config } from "../models/Config";
import { AUTOBackup, BackupType, ConfigGlobalStatus, LowBatteryStop, OnlyWIFIBackup } from "../typing"
import { Cell } from "./Cell"
import { AppStorageV2, ComponentContent, ComposeTitleBar, EditableLeftIconType, EditableTitleBar } from "@kit.ArkUI";
import { Dialog } from "../utils/dialog";
import { FolderSelectDialog } from "../dialogs/FolderSelectDialog";
import { ServerConfig } from "../models/Server";
import { Global } from "../models/Global";
import { About } from "./About";

class Params {
  rootPath: string = ""

  constructor(rootPath: string) {
    this.rootPath = rootPath;
  }
}

@Builder
function buildDirSelect(params: Params) {
  FolderSelectDialog({ rootPath: params.rootPath })
}

@ComponentV2
export struct Settings {
  @Consumer('pageInfos') pageInfos: NavPathStack = new NavPathStack()
  @Local server: ServerConfig = AppStorageV2.connect(ServerConfig, "server", () => ServerConfig.getInstance())!;
  @Local config: Config = AppStorageV2.connect(Config, "config", () => Config.getInstance())!;
  @Local global: Global = AppStorageV2.connect(Global, "global", () => Global.getInstance())!;
  @Local backupTypeValue: string[] = [];
  @Local showBackupTypePopup: boolean = false;
  scroller: Scroller = new Scroller();
  @Local backupTypeOptions: IBestPickerOption[] = [
    { text: '备份所有照片', value: "all" },
    { text: '备份新照片', value: "new" },
  ]
  private backupTypeMap: Record<BackupType, string> = {
    1: "备份所有照片",
    2: "备份新照片"
  }
  private backupTypeDescMap: Record<BackupType, string> = {
    1: "第一次备份相册内所有照片，后续为增量备份",
    2: "只备份当前时间后新增的照片，后续为增量"
  }
  private ctx: UIContext = this.getUIContext();

  private openFolderSelectDialog() {
    Dialog.setContext(this.ctx);
    Dialog.setContentNode(new ComponentContent(this.ctx, wrapBuilder(buildDirSelect), new Params(this.config.backupRootPath)));
    Dialog.setOptions({
      alignment: DialogAlignment.BottomStart,
      isModal: true,
      transition: TransitionEffect.move(TransitionEdge.BOTTOM).animation({ duration: 500, curve: Curve.Ease })
    });
    Dialog.openDialog();
  }

  @Builder
  pickerBuilder() {
    IBestPicker({
      options: this.backupTypeOptions,
      title: "备份范围选择",
      visibleItemCount: 5,
      value: this.backupTypeValue!!,
      onConfirm: (selectedValues) => {
        this.showBackupTypePopup = false
        if (selectedValues[0] == 'all') {
          this.config.backupType = BackupType.ALL;
        } else {
          this.config.backupType = BackupType.NEW;
        }
        this.config.update();
      },
      onCancel: () => {
        this.showBackupTypePopup = false;
      }
    })
  }

  @Builder
  buildLowBatteryStop() {
    Toggle({ type: ToggleType.Switch, isOn: this.config.lowBatteryStop === LowBatteryStop.YES ? true : false })
      .onChange((isOn: boolean) => {
        this.config.lowBatteryStop = isOn ? LowBatteryStop.YES : LowBatteryStop.NO;
        this.config.update();
      })
  }

  @Builder
  buildOnlyWifi() {
    Toggle({ type: ToggleType.Switch, isOn: this.config.onlyWifi === OnlyWIFIBackup.YES ? true : false })
      .onChange((isOn: boolean) => {
        this.config.onlyWifi = isOn ? OnlyWIFIBackup.YES : OnlyWIFIBackup.NO;
        this.config.update();
      })
  }

  @Builder
  buildAuto() {
    Toggle({ type: ToggleType.Switch, isOn: this.config.auto === AUTOBackup.YES ? true : false })
      .onChange((isOn: boolean) => {
        this.config.auto = isOn ? AUTOBackup.YES : AUTOBackup.NO;
        this.config.update();
      })
  }

  aboutToAppear(): void {
    this.backupTypeValue = this.config.backupType == BackupType.ALL ? ['all'] : ['new']
  }

  aboutToDisappear(): void {
    // console.log("设置页面销毁")
  }

  build() {
    Column() {
      Scroll(this.scroller) {
        Column() {
          Cell({
            title: "服务器",
            left: this.server.server,
            content: `登录用户：${this.server.username}`,
            showArrow: true
          })
            .onClick(() => {
              // 跳转到登录页面
              this.pageInfos.pushPath({ name: "login", param: true });
            })
          Cell({
            title: "备份范围",
            left: this.backupTypeMap[this.config.backupType],
            content: this.backupTypeDescMap[this.config.backupType],
            showArrow: true
          })
            .onClick(() => {
              this.showBackupTypePopup = true
            })
          if (this.config.backupRootPath === "") {
            Cell({ title: "备份路径", content: "点击设置", showArrow: true })
              .onClick(() => {
                this.openFolderSelectDialog();
              })
          } else {
            Cell({ title: "备份路径", left: this.config.backupRootPath, showArrow: true })
              .onClick(() => {
                this.openFolderSelectDialog();
              })
          }

          Cell({
            left: "低电量停止备份",
            rightBuilder: () => {
              this.buildLowBatteryStop()
            }
          })
          Cell({
            left: "非WIFI停止备份",
            rightBuilder: () => {
              this.buildOnlyWifi()
            }
          })
          Cell({
            left: "自动备份",
            content: "每次进入APP都自动启动备份，如果关闭需要手动点击“开始备份”或者每个任务的“开始”按钮",
            rightBuilder: () => {
              this.buildAuto()
            }
          })

          Cell({
            left: "隐私协议",
            showArrow: true
          })
            .onClick(() => {
              this.pageInfos.pushPathByName("PrivacyComponent", true);
            })
          Cell({
            left: "用户协议",
            showArrow: true
          })
            .onClick(() => {
              this.pageInfos.pushPathByName("agreement", true);
            })

          About()

          Text("陕ICP备2025065287号-2A")
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: $r('app.float.normal_padding'), bottom: $r('app.float.normal_padding') })

          // 弹出层
          IBestPopup({
            visible: this.showBackupTypePopup!!,
            popupAlign: "bottom",
            contentBuilder: (): void => this.pickerBuilder()
          })
        }
        .padding({ bottom: 30 })
        .width('100%')
      }
    }
    .backgroundColor($r('app.color.ibest_white'))
  }
}