import { IBestButton, IBestNotify } from "@ibestservices/ibest-ui-v2"
import { Global } from "../models/Global";
import { AppStorageV2 } from "@kit.ArkUI";
import { BusinessError, emitter } from "@kit.BasicServicesKit";
import { AUTOBackup, ConfigGlobalStatus, LoginStatus, TaskDoing } from "../typing";
import { checkPermissions } from "../utils/permission";
import { common } from "@kit.AbilityKit";
import { Config } from "../models/Config";
import { TaskItem } from "../models/TaskItem";

@ComponentV2
export struct TaskCheck {
  @Local config: Config = AppStorageV2.connect(Config, "config", () => Config.getInstance())!;
  @Local global: Global = AppStorageV2.connect(Global, "global", () => Global.getInstance())!;
  @Local creatingTask: boolean = false;
  @Local loadingText: string = "正在收集需要备份的项目..."

  private ctxUIAbility: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    // 监听触发新建任务
    emitter.on(Global.START_COLLECT_PHOTO_EVENT, () => {
      console.log(`接收到收集带备份项目事件, creatingTask=${this.creatingTask}`)
      this.startCreateTask();
    })
  }

  checkPerm(): Promise<boolean> {
    return new Promise((resolve) => {
      checkPermissions(this.ctxUIAbility, 'ohos.permission.READ_IMAGEVIDEO').then((rs) => {
        if (rs) {
          resolve(true)
        } else {
          IBestNotify.show({
            message: "未授权访问相册，请到'设置 > 应用和元服务 > 相册备份'中打开'图片和视频 -> 仅读取'权限后再重新打开本应用",
            type: "warning",
            duration: 3000
          })
          resolve(false);
        }
      })
    })
  }

  // 是否开源收集照片并生成任务
  async canCreateTask(): Promise<boolean> {
    if (this.global.loginStatus === LoginStatus.LOGIN && this.global.configGlobalStatus === ConfigGlobalStatus.YES) {
      // 检查是否授权读取相册
      if (!(await this.checkPerm())) {
        console.warn(`无法启动收集带备份任务，未授权`)
        return false;
      }
      // 如果正在创建备份任务
      if (this.creatingTask) {
        console.warn(`无法启动收集带备份任务，有运行中的创建任务`)
        return false;
      }
      return true;
    }
    return false;
  }

  async startCreateTask(): Promise<boolean> {
    if (!(await this.canCreateTask())) {
      console.warn(`无法启动收集带备份任务，条件不满足`)
      return false;
    }
    console.log(`开始创建TaskItems`);
    this.creatingTask = true;
    this.global.taskGlobalStatus = TaskDoing.YES;
    try {
      await TaskItem.createTask(this.ctxUIAbility, this.config)
    } catch (e) {
      let err = e as BusinessError;
      console.error(`创建TaskItems失败: code=${err.code}, msg=${err.message}`)
    } finally {
      animateTo({ duration: 1000, curve: Curve.EaseIn }, () => {
        this.creatingTask = false;
      })
      emitter.emit(Global.COLLECT_PHOTO_FINISH_EVENT);
      setTimeout(() => {
        if (this.config.auto === AUTOBackup.YES) {
          // 触发任务执行
          emitter.emit(Global.START_WAIT_TASK_EVENT);
        }
      }, 1000)
    }
    return true;
  }

  build() {
    Column() {
      IBestButton({
        text: '开始备份',
        type: this.creatingTask ? 'default' : 'primary',
        loadingText: this.loadingText,
        loading: this.creatingTask
      })
        .onClick(() => {
          this.startCreateTask().then((exists: boolean) => {
            this.creatingTask = false;
            emitter.emit(Global.COLLECT_PHOTO_FINISH_EVENT, { data: { exists: exists } })
          })
        })
    }
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.ibest_white'))
    .width('100%')
    .padding($r("app.float.normal_padding"))
  }
}