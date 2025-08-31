import { AccessStatus, ConfigGlobalStatus, LoginStatus, TaskDoing } from "../typing"

@ObservedV2
export class Global {
  @Trace AccessStatus: AccessStatus = AccessStatus.NO;
  @Trace loginStatus: LoginStatus = LoginStatus.INIT // 默认正在初始化
  @Trace taskGlobalStatus: TaskDoing = TaskDoing.NO // 默认没有运行中的任务
  @Trace configGlobalStatus: ConfigGlobalStatus = ConfigGlobalStatus.NO; // 没有配置项
  @Trace processId: number = 0; // 运行中的任务
  @Trace tabIndex: number = 0; // tab导航当前选中的页面
  @Trace preTotal: number = 0;

  private static _instance: Global | null = null;

  static getInstance() {
    if (Global._instance === null) {
      Global._instance = new Global();
    }
    return Global._instance;
  }

  static COLLECT_PHOTO_FINISH_EVENT = 'collect_photo_finish'; // 收集照片完成
  static STOP_BACKGROUND_EVENT = 'stop_background'; // 触发任务停止
  static STOP_TASK_EVENT = 'stop_task'; // 触发任务停止
  static UPDATE_TASK_ITEM_EVENT = 'update_task_item_event'; // 开始执行某个任务
  static EXIT_EVENT = "APP.EXIT";
}