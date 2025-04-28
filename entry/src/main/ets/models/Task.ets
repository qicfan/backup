import { BackupType, TaskItemStatus, TaskStatus, TaskType } from "../typing";
import { DB } from "./DB";
import { relationalStore } from "@kit.ArkData";
import { BusinessError, emitter } from "@kit.BasicServicesKit";
import { Global } from "./Global";
import { Photos } from "../utils/photos";
import { TaskItem } from "./TaskItem";
import { Config } from "./Config";

/**
 * 备份任务
 */
@ObservedV2
export class Task {
  id: number = 0;
  type: TaskType = TaskType.AUTO
  @Trace total: number = 0;
  @Trace size: number = 0;
  @Trace uploadedSize: number = 0;
  @Trace success: number = 0;
  @Trace failed: number = 0;
  @Trace status: TaskStatus = TaskStatus.WAIT
  @Trace cancelReason: string = "";
  createdAt: number = 0;
  updatedAt: number = 0;
  public preUploadedSize = 0;
  static TABLE_NAME = 'task'

  // 从数据库中查询最新的值
  async fetch() {
    let predicates = new relationalStore.RdbPredicates(Task.TABLE_NAME);
    predicates.equalTo("id", this.id).limitAs(1)
    try {
      const rs = await DB.getInstance().store?.query(predicates);
      if (!rs || rs.rowCount <= 0) {
        return false
      }
      while (rs.goToNextRow()) {
        this.type = rs.getLong(rs.getColumnIndex('type'))
        this.size = rs.getLong(rs.getColumnIndex('size'))
        this.uploadedSize = rs.getLong(rs.getColumnIndex('uploaded_size'))
        this.total = rs.getLong(rs.getColumnIndex('total'))
        this.success = rs.getLong(rs.getColumnIndex('success'))
        this.failed = rs.getLong(rs.getColumnIndex('failed'))
        this.status = rs.getLong(rs.getColumnIndex('status'))
        this.cancelReason = rs.getString(rs.getColumnIndex('cancel_reason'))
        this.createdAt = rs.getLong(rs.getColumnIndex('created_at'))
        this.updatedAt = rs.getLong(rs.getColumnIndex('updated_at'))
        return true;
      }
    } catch (e) {
      let err = e as BusinessError;
      console.log(`${err.code} => ${err.message}`)
      return false;
    }
    return false;
  }

  // 将状态修改为待执行
  async wait() {
    this.status = TaskStatus.WAIT;
    await this.updateStatus();
  }

  // 将状态修改为执行中
  async start() {
    this.status = TaskStatus.PROCESS;
    await this.updateStatus();
  }

  async finish(reason?: string): Promise<void> {
    console.log(`任务停止原因1：${reason}`)
    await this.fetch();
    if (reason) this.cancelReason = reason;
    console.log(`任务停止原因2：${this.cancelReason}`)
    if ((this.success + this.failed) < this.total) {
      console.log(`状态改为等待，failed: ${this.failed}, success: ${this.success}`)
      return await this.wait();
    }
    this.status = TaskStatus.FINISH;
    console.log(`状态改为完成`)
    return await this.updateStatus();
  }

  async updateStatus() {
    this.updatedAt = Math.floor(Date.now() / 1000);
    const updateBucket: relationalStore.ValuesBucket = {
      "status": this.status,
      "cancel_reason": this.cancelReason,
      "updated_at": this.updatedAt,
    };
    let predicates = new relationalStore.RdbPredicates(Task.TABLE_NAME);
    predicates.equalTo("id", this.id)
    try {
      await DB.getInstance().store?.update(updateBucket, predicates);
    } catch (err) {
      console.error(`task update failed, code is ${err.code},message is ${err.message}`);
    }
  }

  async updateSuccess(count: number = 1) {
    let sql: string;
    if (count > 0) {
      sql = `UPDATE ${Task.TABLE_NAME} SET success = success + ${count} WHERE id=?`
    } else {
      sql = `UPDATE ${Task.TABLE_NAME} SET success = success - ${count} WHERE id=?`
    }
    try {
      await DB.getInstance().store?.executeSql(sql, [this.id]);
      await this.fetch();
    } catch (err) {
      console.error(`更新任务成功计数失败, code is ${err.code},message is ${err.message}`);
    }
  }

  async updateFailed(count: number = 1) {
    let sql: string;
    if (count > 0) {
      sql = `UPDATE ${Task.TABLE_NAME} SET failed = failed + ${count} WHERE id=?`
    } else {
      sql = `UPDATE ${Task.TABLE_NAME} SET failed = failed - ${count} WHERE id=?`
    }
    try {
      await DB.getInstance().store?.executeSql(sql, [this.id]);
      await this.fetch();
    } catch (err) {
      console.error(`更新任务失败计数失败, code is ${err.code},message is ${err.message}`);
    }
  }

  async updateUploadedSize(uploadedSize: number) {
    this.uploadedSize = this.preUploadedSize + uploadedSize;
    this.updatedAt =  Math.floor(Date.now() / 1000);
    const updateBucket: relationalStore.ValuesBucket = {
      "uploaded_size": this.uploadedSize,
      "updated_at": this.updatedAt,
    };
    let predicates = new relationalStore.RdbPredicates(Task.TABLE_NAME);
    predicates.equalTo("id", this.id)
    try {
      await DB.getInstance().store?.update(updateBucket, predicates);
    } catch (err) {
      console.error(`task uploaded size update failed, code is ${err.code},message is ${err.message}`);
    }
  }

  async save() {
    const insertBucket: relationalStore.ValuesBucket = {
      "id": this.id,
      "type": this.type,
      "size": this.size,
      "uploaded_size": this.uploadedSize,
      "total": this.total,
      "success": this.success,
      "failed": this.failed,
      "status": this.status,
      "cancel_reason": this.cancelReason,
      "created_at": this.createdAt,
      "updated_at": this.updatedAt,
    };
    try {
        await DB.getInstance().store?.insert('task', insertBucket);
      // console.info(`task Insert row: ${rowId}`);
    } catch (err) {
      console.error(`task Insert failed, code is ${err.code},message is ${err.message}`);
    }
  }

  // 查询任务详情
  async getFailItems(page: number = 1, pageSize: number = 100) {
    const items: TaskItem[] = [];
    const offset = (page - 1) * pageSize;
    let predicates = new relationalStore.RdbPredicates(TaskItem.TABLE_NAME);
    predicates.equalTo("task_id", this.id)
      .and()
      .in("status", [TaskItemStatus.FAIL])
      .limitAs(pageSize)
      .offsetAs(offset)
    try {
      const rs = await DB.getInstance().store?.query(predicates);
      if (rs === undefined) {
        return [];
      }
      console.log(`task ${this.id}查询到 ${rs?.rowCount}条 item`)
      if (rs.rowCount <= 0) {
        return [];
      }
      while (rs.goToNextRow()) {
        const taskItem = TaskItem.getInstance(rs);
        taskItem.task = this;
        items.push(taskItem)
      }
      rs.close();
      return items
    } catch (error) {
      let err = error as BusinessError;
      console.log(`${err.code} => ${err.message}`)
      return [];
    }
  }

  // 查询任务详情
  async getWaitItems(page: number = 1, pageSize: number = 100): Promise<relationalStore.ResultSet | null> {
    const items: TaskItem[] = [];
    const offset = (page - 1) * pageSize;
    let predicates = new relationalStore.RdbPredicates(TaskItem.TABLE_NAME);
    predicates.equalTo("task_id", this.id)
      .and()
      .in("status", [TaskItemStatus.WAIT, TaskItemStatus.UPLOADING])
      .limitAs(pageSize)
      .offsetAs(offset)
      .orderByAsc('id')
    const SQL = `SELECT * FROM ${TaskItem.TABLE_NAME} WHERE task_id=? AND status IN (?, ?) AND uploaded_size < size ORDER BY id ASC LIMIT 0, ?`;
    try {
      const rs = await DB.getInstance().store?.querySql(SQL, [this.id, TaskItemStatus.WAIT, TaskItemStatus.UPLOADING, pageSize]);
      if (rs === undefined) {
        return null;
      }
      if (rs.rowCount <= 0) {
        return null;
      }
      // while (rs.goToNextRow()) {
      //   const taskItem = TaskItem.getInstance(rs);
      //   taskItem.task = this;
      //   items.push(taskItem)
      // }
      // rs.close();
      return rs
    } catch (error) {
      let err = error as BusinessError;
      console.log(`${err.code} => ${err.message}`)
      return null;
    }
  }

  // 查询任务详情
  async getProcessItems() {
    let item: TaskItem | undefined = undefined;
    let predicates = new relationalStore.RdbPredicates(TaskItem.TABLE_NAME);
    // predicates.equalTo("task_id", this.id).limitAs(pageSize).offsetAs(offset)
    predicates.equalTo("task_id", this.id)
      .and()
      .equalTo("status", TaskItemStatus.UPLOADING)
      .limitAs(1)
      .orderByAsc('id')
    try {
      const rs = await DB.getInstance().store?.query(predicates);
      if (rs === undefined || rs.rowCount <= 0) {
        return item;
      }
      while (rs.goToNextRow()) {
        item = TaskItem.getInstance(rs);
        item.task = this;
      }
      rs.close();
    } catch (error) {
      let err = error as BusinessError;
      console.log(`${err.code} => ${err.message}`)
    } finally {
      return item;
    }
  }

  static async getList(page: number = 1, pageSize: number = 20) {
    const offset = (page - 1) * pageSize;
    let predicates = new relationalStore.RdbPredicates(Task.TABLE_NAME);
    predicates.orderByDesc('id').limitAs(pageSize).offsetAs(offset)
    try {
      const rs = await DB.getInstance().store?.query(predicates);
      if (rs === undefined) {
        return [];
      }
      if (rs.rowCount <= 0) {
        return [];
      }
      const items: Task[] = []
      while (rs.goToNextRow()) {
        const taskItem = new Task()
        taskItem.id = rs.getLong(rs.getColumnIndex('id'))
        taskItem.type = rs.getLong(rs.getColumnIndex('type'))
        taskItem.size = rs.getLong(rs.getColumnIndex('size'))
        taskItem.uploadedSize = rs.getLong(rs.getColumnIndex('uploaded_size'))
        taskItem.total = rs.getLong(rs.getColumnIndex('total'))
        taskItem.success = rs.getLong(rs.getColumnIndex('success'))
        taskItem.failed = rs.getLong(rs.getColumnIndex('failed'))
        taskItem.status = rs.getLong(rs.getColumnIndex('status'))
        taskItem.cancelReason = rs.getString(rs.getColumnIndex('cancel_reason'))
        taskItem.createdAt = rs.getLong(rs.getColumnIndex('created_at'))
        taskItem.updatedAt = rs.getLong(rs.getColumnIndex('updated_at'))
        items.push(taskItem)
      }
      rs.close();
      return items
    } catch (e) {
      let err = e as BusinessError;
      console.log(`${err.code} => ${err.message}`)
      return [];
    }
  }

  // 查询待执行的任务
  static async getWaitList() {
    let predicates = new relationalStore.RdbPredicates(Task.TABLE_NAME);
    predicates.in("status", [TaskStatus.WAIT, TaskStatus.PROCESS]).orderByAsc('id').limitAs(1)

    try {
      const rs = await DB.getInstance().store?.query(predicates);
      if (!rs || rs.rowCount <= 0) {
        return undefined
      }
      while (rs.goToNextRow()) {
        const task = new Task()
        task.id = rs.getLong(rs.getColumnIndex('id'))
        task.type = rs.getLong(rs.getColumnIndex('type'))
        task.size = rs.getLong(rs.getColumnIndex('size'))
        task.uploadedSize = rs.getLong(rs.getColumnIndex('uploaded_size'))
        task.total = rs.getLong(rs.getColumnIndex('total'))
        task.success = rs.getLong(rs.getColumnIndex('success'))
        task.failed = rs.getLong(rs.getColumnIndex('failed'))
        task.status = rs.getLong(rs.getColumnIndex('status'))
        task.cancelReason = rs.getString(rs.getColumnIndex('cancel_reason'))
        task.createdAt = rs.getLong(rs.getColumnIndex('created_at'))
        task.updatedAt = rs.getLong(rs.getColumnIndex('updated_at'))
        rs.close();
        return task;
      }
    } catch (e) {
      let err = e as BusinessError;
      console.log(`${err.code} => ${err.message}`)
      return undefined;
    }
    return;
  }

  // 修复意外退出导致的任务状态错误
  static async repair(processTaskId: number): Promise<boolean> {
    if (processTaskId > 0) {
      return true;
    }
    // 更新所有运行中的任务为待运行
    const updateBucket: relationalStore.ValuesBucket = {
      "status": TaskStatus.WAIT,
      "updated_at": Math.floor(Date.now() / 1000)
    };
    let predicates = new relationalStore.RdbPredicates(Task.TABLE_NAME);
    predicates.equalTo("status", TaskStatus.PROCESS)
    try {
      await DB.getInstance().store?.update(updateBucket, predicates);
    } catch (err) {
      console.error(`修正运行中的任务状态失败, code is ${err.code},message is ${err.message}`);
    }
    return false;
  }

  /**
   * 收集相册照片信息，决定是否创建任务
   *
   */
  static async createTask(ctx: Context, config: Config) {
    let lastId: number = 0;
    let lastTimestamp: number = 0;
    if (config.backupType === BackupType.NEW) {
      // 只备份新数据，开始时间是APP第一次打开时间
      lastTimestamp = config.createdAt;
    }
    let predicates = new relationalStore.RdbPredicates(Task.TABLE_NAME);
    predicates.orderByDesc('id').limitAs(1)
    const rs = await DB.getInstance().store?.query(predicates)
    if (rs === undefined || rs.rowCount <= 0) {
      lastId = 1;
    } else {
      while (rs.goToNextRow()) {
        lastId = rs.getLong(rs.getColumnIndex('id')) + 1
        lastTimestamp = rs.getLong(rs.getColumnIndex('created_at'))
        break;
      }
    }
    rs?.close();
    let page = 1;
    const pageSize = 100;
    let total = 0;
    let size = 0;
    while (true) {
      // 1. 收集相册内容，并且写入taskitem表
      const items = await Photos.getPhotos(ctx, lastTimestamp, page, pageSize)
      // 写入数据库
      if (items.length === 0) {
        break;
      }
      for (let item of items) {
        item.taskId = lastId;
        const rs = await item.save();
        if (rs) {
          size += item.size + item.videoSize;
          total++;
        }
      }
      if (items.length < pageSize) {
        break;
      }
      page++
    }
    // 2. 写入task表
    if (total === 0) {
      // 没有新照片，什么也不用干
      emitter.emit(Global.COLLECT_PHOTO_FINISH_EVENT, { data: { exists: false } })
      return;
    }
    const task = new Task();
    task.id = lastId;
    task.type = TaskType.AUTO;
    task.size = size;
    task.uploadedSize = 0;
    task.total = total;
    task.success = 0;
    task.failed = 0;
    task.status = TaskStatus.WAIT;
    task.cancelReason = "";
    task.createdAt = Math.floor(Date.now() / 1000);
    task.updatedAt = 0;
    await task.save();
    emitter.emit(Global.COLLECT_PHOTO_FINISH_EVENT, { data: { exists: true } })
    return;
  }
}