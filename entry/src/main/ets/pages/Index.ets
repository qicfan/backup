import { IBestButton, IBestNotify } from "@ibestservices/ibest-ui-v2";
import { ServerConfig } from "../models/Server";
import { AppStorageV2 } from "@kit.ArkUI";
import { abilityAccessCtrl, common, WantAgent, wantAgent } from "@kit.AbilityKit";
import { Global } from "../models/Global";
import { AccessStatus, ConfigGlobalStatus, LoginStatus, LowBatteryStop, OnlyWIFIBackup, TaskDoing } from "../typing";
import { Config } from "../models/Config";
import { Settings } from "../components/Settings";
import { Login } from "../components/Login";
import { WebDav } from "../utils/webdav";
import { TaskList } from "../components/TaskList";
import { BusinessError, emitter } from "@kit.BasicServicesKit";
import { Task } from "../models/Task";
import { backgroundTaskManager } from "@kit.BackgroundTasksKit";
import { notificationManager } from "@kit.NotificationKit";
import { TaskItem } from "../models/TaskItem";
import { checkPermissionGrant } from "../utils/permission";
import { getBatteryLevel, getCurrentNetType } from "../utils/tool";
import { connection } from "@kit.NetworkKit";

@Entry
@ComponentV2
struct Index {
  @Local server: ServerConfig = AppStorageV2.connect(ServerConfig, "server", () => new ServerConfig())!;
  @Local config: Config = AppStorageV2.connect(Config, "config", () => new Config())!;
  @Local webdav: WebDav = AppStorageV2.connect(WebDav, "webdav", () => new WebDav())!;
  @Local global: Global = AppStorageV2.connect(Global, "global", () => new Global())!;
  private ctxUIAbility: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  @Provider('pageInfos') pageInfos: NavPathStack = new NavPathStack()
  private stop: boolean = false; // 是否停止执行
  private jobId: number = 0;
  @Local creatingTask: boolean = false;

  aboutToAppear() {
    this.server.queryAsset().then((exists: boolean) => {
      if (!exists) {
        // 沒有添加服務器，彈出添加窗口
        return this.pageInfos.replacePath({ name: "login" })
      } else {
        this.global.loginStatus = LoginStatus.NO_LOGIN;
        // 检查服务器是否可用
        this.webdav.updateSerConfig(this.server);
        this.webdav.valid().then((rs) => {
          if (rs) {
            this.global.loginStatus = LoginStatus.LOGIN;
          } else {
            // 登录失败，重新登录
            return this.pageInfos.replacePath({ name: "login" })
          }
        })
      }
      this.config.init().then((exists: number) => {
        if (exists != 1) {
          return this.pageInfos.replacePath({ name: "Settings" })
        } else {
          this.global.configGlobalStatus = ConfigGlobalStatus.YES
        }
      }).catch(() => {
        return this.pageInfos.replacePath({ name: "Settings" })
      })
    }).catch(() => {
      return this.pageInfos.replacePath({ name: "login" })
    })
    // 等开始收集相册内的新内容并生成任务
    emitter.on(Global.START_COLLECT_PHOTO_EVENT, () => {
      this.startCreateTask()
    })

    // 开始执行未完成的任务
    emitter.on(Global.START_WAIT_TASK_EVENT, (data) => {
      console.log("收到开始任务通知：" + data.data?.id)
      const taskId: number = data.data?.id;
      this.startTask(taskId)
    })

    // 暂停任务
    emitter.on(Global.STOP_TASK_EVENT, (data) => {
      console.log("收到暂停任务通知：" + data.data?.id)
      const taskId: number = data.data?.id;
      this.stopTask(taskId, true)
    })
  }

  onPageShow(): void {
    // 从后台转入前台时触发生成新任务
    setTimeout(() => {
      emitter.emit(Global.START_COLLECT_PHOTO_EVENT);
    }, 3000)
  }

  checkPerm(): Promise<boolean> {
    return new Promise((resolve) => {
      checkPermissionGrant('ohos.permission.READ_IMAGEVIDEO').then((s) => {
        if (s === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          // 已授权
          this.global.AccessStatus = AccessStatus.YES;
          resolve(true)
        } else {
          IBestNotify.show({
            message: "未授权访问相册，请到'设置 > 应用和元服务 > 相册备份'中打开'图片和视频 -> 仅读取'权限后再重新打开本应用",
            type: "warning",
            duration: 3000
          })
          this.global.AccessStatus = AccessStatus.NO;
          resolve(false)
        }
      })
    })

  }

  checkBattery() {
    if (this.config.lowBatteryStop === LowBatteryStop.YES) {
      if (getBatteryLevel() <= 15) {
        IBestNotify.show({
          message: "已打开低电量不备份，当前电量低于15%，不启动备份任务",
          type: "warning",
          duration: 3000
        })
        return false;
      }
    }
    return true;
  }

  async checkWifi() {
    if (this.config.onlyWifi === OnlyWIFIBackup.YES) {
      const netType = await getCurrentNetType();
      if (netType == connection.NetBearType.BEARER_CELLULAR) {
        IBestNotify.show({
          message: "已打开仅wifi备份，当前使用移动网络，不启动备份任务",
          type: "warning",
          duration: 3000
        })
        return false;
      }
    }
    return true;
  }

  // 是否开源启动任务执行
  async canStart(): Promise<boolean> {
    // 检查是否授权读取相册
    if (!(await this.checkPerm())) {
      return false;
    }
    // 如果打开了低电量暂停任务，则检查电量
    if (!this.checkBattery()) {
      return false;
    }
    // 如果打开了仅WIFI备份，则检查网络状态
    if (!(await this.checkWifi())) {
      return false;
    }
    if (this.config.backupRootPath === "") {
      IBestNotify.show({
        message: "请先设置备份路径",
        type: "warning",
        duration: 3000
      })
      return false;
    }
    // 如果已经触发了停止，则不会开始执行新任务
    if (this.stop) {
      return false;
    }
    return true;
  }

  // 是否开源收集照片并生成任务
  async canCreateTask(): Promise<boolean> {
    // 检查是否授权读取相册
    if (!(await this.checkPerm())) {
      return false;
    }
    // 如果正在创建备份任务
    if (this.creatingTask) {
      return false;
    }
    return true;
  }

  // 开始任务
  async startTask(taskId?: number): Promise<boolean> {
    if (!this.canStart()) {
      return false;
    }
    if (this.global.processId > 0) {
      // 暂停该任务，然后启动新任务
      await this.stopTask(this.global.processId);
    }
    let waitTask: Task | undefined;
    if (!taskId) {
      waitTask = await Task.getWaitList();
    } else {
      waitTask = new Task();
      waitTask.id = taskId;
      await waitTask.fetch()
    }
    if (waitTask === undefined) {
      // 没有要执行的任务
      console.log("没有要执行的任务");
      return false;
    }
    console.log("开始执行任务：" + waitTask.id)
    this.stop = false;
    this.global.processId = waitTask.id;
    this.startBackground(waitTask)
    return true;
  }

  // 停止任务
  async stopTask(taskOrId: number | Task, pause: boolean = false) {
    let task: Task;
    if (typeof taskOrId == "number") {
      task = new Task();
      task.id = taskOrId;
      await task.fetch()
    } else {
      task = taskOrId;
    }
    this.global.processId = 0;
    this.jobId = 0;
    if (pause) this.stop = true;
    await task.finish();
    // 取消长时任务
    backgroundTaskManager.stopBackgroundRunning(this.ctxUIAbility);
  }



  async startCreateTask(): Promise<boolean> {
    if (!this.canCreateTask()) {
      return false;
    }
    console.log("准备生成新任务")
    IBestNotify.show({
      message: "正在扫描新照片并生成备份任务...",
      type: "warning",
      duration: 500000
    })
    try {
      await Task.createTask(getContext(this))
    } catch (e) {

    } finally {
      setTimeout(() => {
        IBestNotify.close();
        // 触发任务执行
        emitter.emit(Global.START_WAIT_TASK_EVENT);
      }, 1000)
    }
    return true;
  }

  startBackground(task: Task) {
    this.webdav.updateSerConfig(this.server)
    const wantAgentInfo: wantAgent.WantAgentInfo = {
      // 点击通知后，将要执行的动作列表
      wants: [{ bundleName: "com.xaxx.backup", abilityName: "EntryAbility" }],
      // 点击通知后，动作类型
      actionType: wantAgent.OperationType.START_ABILITY,
      // 使用者自定义的一个私有值
      requestCode: 0,
      // 点击通知后，动作执行属性
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    try {
      // 监听停止长时任务
      backgroundTaskManager.on("continuousTaskCancel", () => {
        // 标记任务状态，然后停止上传
        this.stopTask(task);
      });
      // 通过wantAgent模块下getWantAgent方法获取WantAgent对象
      wantAgent.getWantAgent(wantAgentInfo).then((wantAgentObj: WantAgent) => {
        try {
          let list: Array<string> = ["dataTransfer"];
          backgroundTaskManager.startBackgroundRunning(this.ctxUIAbility, list, wantAgentObj)
            .then(async (res: backgroundTaskManager.ContinuousTaskNotification) => {
              console.info("开始执行长时任务，上传照片");
              // 触发UI更新，显示任务进度
              emitter.emit(Global.UPDATE_TASK_EVENT, { data: { id: task.id } })
              // 对于上传下载类的长时任务，应用可以使用res中返回的notificationId来更新通知，比如发送带进度条的模板通知。
              this.jobId = res.notificationId;
              console.info("长时任务ID: " + this.jobId);
              // 将任务标记为开始执行
              await task.start();
              emitter.emit(Global.UPDATE_TASK_EVENT, { data: { id: task.id } })
              console.log(`任务 ${task.id} 开始执行...`)
              let page = 1;
              let pageSize = 100;
              const updateProgressHandleId = setTimeout(() => {
                if (this.jobId <= 0) {
                  clearTimeout(updateProgressHandleId);
                  return ;
                }
                // 每秒更新一次任务进度
                this.updateProcess(task);
                return ;
              }, 1000)
              while (true) {
                let curTotal = 0;
                const items: TaskItem[] = await task.getWaitItems(page, pageSize)
                for (let item of items) {
                  if (this.stop)  break;
                  if (!this.checkBattery()) {
                    // 电量低于15%，停止
                    this.stop = true;
                    break;
                  }
                  if (!(await this.checkWifi())) {
                    // 非wifi网络，停止
                    this.stop = true;
                    break;
                  }
                  curTotal++
                  task.preUploadedSize = task.uploadedSize;
                  item.updateWebDav(this.webdav, this.config)
                  try {
                    const rs = await item.upload()
                    if (rs) {
                      task.success++
                    } else {
                      task.failed++;
                    }
                    await task.updateStat(task.success, task.failed);
                  } catch (e) {
                    task.failed++;
                    await task.updateStat(task.success, task.failed);
                  } finally {
                    // 触发UI更新
                    emitter.emit(Global.UPDATE_TASK_EVENT, { data: { id: task.id } })
                  }
                }
                if (curTotal >= pageSize && !this.stop) {
                  page++;
                  continue;
                }
                // 完成任务
                this.stopTask(task)
                setTimeout(() => {
                  // 触发UI刷新
                  emitter.emit(Global.UPDATE_TASK_EVENT, { data: { id: task.id } })
                  if (!this.stop) {
                    // 触发下一次执行
                    emitter.emit(Global.START_WAIT_TASK_EVENT)
                  }
                }, 1000)
                break;
              }
            })
            .catch((error: BusinessError) => {
              console.error(`启动长时任务失败. code is ${error.code} message is ${error.message}`);
            });
        } catch (error) {
          console.error(`启动长时任务失败. code is ${(error as BusinessError).code} message is ${(error as BusinessError).message}`);
        }
      });
    } catch (error) {
      console.error(`Operation getWantAgent failed. code is ${(error as BusinessError).code} message is ${(error as BusinessError).message}`);
    }
  }

  // 应用更新进度
  updateProcess(task: Task) {
    // 应用定义下载类通知模版
    const cur = task.success + task.failed
    const process: number = Math.floor(task.uploadedSize / task.size * 100);

    let downLoadTemplate: notificationManager.NotificationTemplate = {
      name: 'downloadTemplate', // 当前只支持downloadTemplate，保持不变
      data: {
        title: `正在备份照片`, // 必填。
        fileName: `进度：${cur}/${task.total}`, // 必填。
        progressValue: process, // 应用更新进度值，自定义。
      }
    };
    let request: notificationManager.NotificationRequest = {
      content: {
        // 系统实况类型，保持不变
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_SYSTEM_LIVE_VIEW,
        systemLiveView: {
          typeCode: 8, // 上传下载类型需要填写 8，当前仅支持此类型。保持不变
          title: "正在备份照片", // 应用自定义
          text: `进度：${cur}/${task.total}`, // 应用自定义
          capsule: {
            title: `备份进度：${cur}/${task.total}`
          }
        }
      },
      id: this.jobId, // 必须是申请长时任务返回的id，否则应用更新通知失败。
      notificationSlotType: notificationManager.SlotType.LIVE_VIEW, // 实况窗类型，保持不变
      template: downLoadTemplate // 应用需要设置的模版名称
    };

    try {
      notificationManager.publish(request).then(() => {
      }).catch((err: BusinessError) => {
        console.error(`更新长时任务进度失败: code: ${err.code}. msg: ${err.message}`);
      });
    } catch (err) {
      console.error(`更新长时任务进度失败: code: ${err.code}. msg: ${err.message}`);
    }
  }

  @Builder
  PageMap(name: string) {
    if (name === "login") {
      Login()
    }
    if (name === "Settings") {
      Settings()
    }
  }

  build() {
    Navigation(this.pageInfos) {
      Column() {
        TaskList()
          .width('100%')
          .layoutWeight(1)
        Column() {
          IBestButton({
            text: '开始备份',
            type: (this.global.taskGlobalStatus == TaskDoing.YES) ? 'default' : 'primary',
            loadingText: "操作中...",
            loading: this.global.taskGlobalStatus == TaskDoing.YES
          })
            .onClick(() => {
              this.global.taskGlobalStatus = TaskDoing.YES;
              emitter.emit(Global.START_COLLECT_PHOTO_EVENT);
            })
        }
        .width('100%')
        .margin({ bottom: $r("app.float.normal_padding") })
      }
    }
    .title("相册备份")
    .navDestination(this.PageMap)
    .mode(NavigationMode.Stack)
    .menus([
      {
        value: "设置", icon: $r("app.media.gearshape"), action: () => {
        this.pageInfos.pushPath({ name: "Settings" })
      }
      }
    ])
    .backgroundColor($r('app.color.ibest_background'))
    .width('100%')
    .height('100%')
  }
}