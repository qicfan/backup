import { IBestNotify, IBestPicker, IBestPickerOption, IBestPopup } from "@ibestservices/ibest-ui-v2"
import { Config } from "../models/Config";
import { BackupType, ConfigGlobalStatus, LowBatteryStop, OnlyWIFIBackup } from "../typing"
import { Cell } from "./Cell"
import { AppStorageV2, ComponentContent } from "@kit.ArkUI";
import { Dialog } from "../utils/dialog";
import { FolderSelectDialog } from "../dialogs/FolderSelectDialog";
import { ServerConfig } from "../models/Server";
import { Global } from "../models/Global";
import { About } from "./About";

class Params {
  rootPath: string = ""
  close: () => void = () => {
  }

  constructor(rootPath: string, close: () => void) {
    this.rootPath = rootPath;
    this.close = close
  }
}

@Builder
function buildLogin(params: Params) {
  FolderSelectDialog({ rootPath: params.rootPath, close: params.close })
}

@ComponentV2
export struct Settings {
  @Consumer('pageInfos') pageInfos: NavPathStack = new NavPathStack()
  @Local server: ServerConfig = AppStorageV2.connect(ServerConfig, "server", () => new ServerConfig())!;
  @Local global: Global = AppStorageV2.connect(Global, "global", () => new Global())!;
  @Local config: Config = AppStorageV2.connect(Config, "config", () => new Config())!;
  @Local backupTypeValue: string[] = [];
  @Local showBackupTypePopup: boolean = false
  @Local backupTypeOptions: IBestPickerOption[] = [
    { text: '备份所有照片', value: "all" },
    { text: '备份新照片', value: "new" },
  ]
  private ctx: UIContext = this.getUIContext();
  // 登录弹窗的节点
  private loginDialogContentNode: ComponentContent<Object> =
    new ComponentContent(this.ctx, wrapBuilder(buildLogin), new Params(this.config.backupRootPath, this.closeDialog))

  private openFolderSelectDialog() {
    Dialog.setContext(this.ctx);
    Dialog.setContentNode(this.loginDialogContentNode);
    Dialog.setOptions({
      alignment: DialogAlignment.BottomStart,
      isModal: true,
      transition: TransitionEffect.move(TransitionEdge.BOTTOM).animation({ duration: 500, curve: Curve.Ease })
    });
    Dialog.openDialog();
  }

  private closeDialog() {
    Dialog.closeDialog();
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

  aboutToAppear(): void {
    this.backupTypeValue = this.config.backupType == BackupType.ALL ? ['all'] : ['new']
  }

  checkConfig() {

  }

  build() {
    NavDestination() {
      Scroll() {
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
          if (this.config.backupType === BackupType.ALL) {
            Cell({
              title: "备份范围",
              left: "备份所有照片",
              content: "第一次备份相册内所有照片，后续为增量备份",
              showArrow: true
            })
              .onClick(() => {

                this.showBackupTypePopup = true
              })
          } else {
            Cell({
              title: "备份范围",
              left: "备份新照片",
              content: "只备份当前时间后新增的照片，后续为增量",
              showArrow: true
            })
              .onClick(() => {
                this.showBackupTypePopup = true
              })
          }
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

          About()

          // 弹出层
          IBestPopup({
            visible: this.showBackupTypePopup!!,
            popupAlign: "bottom",
            contentBuilder: (): void => this.pickerBuilder()
          })
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
    }
    .title("备份规则设置")
    .onWillDisappear(() => {
      this.checkConfig()
    })
    .menus([
      {
        value: "保存",
        icon: $r("sys.media.ohos_ic_public_ok"),
        action: () => {
          if (this.config.backupRootPath !== "") {
            this.global.configGlobalStatus = ConfigGlobalStatus.YES;
            this.pageInfos.pop()
          } else {
            // 提示设置备份目录
            IBestNotify.show({
              message: "请设置备份路径",
              duration: 3000
            })
          }

        }
      }
    ])
    .backgroundColor($r('app.color.ibest_background'))
  }
}