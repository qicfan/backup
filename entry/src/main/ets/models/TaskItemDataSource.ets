import { ServerPhotoItem } from "../utils/server";
import { TaskItem } from "./TaskItem";

export class BasicDataSource implements IDataSource {
  private listeners: DataChangeListener[] = [];
  private originDataArray: TaskItem[] = [];

  public totalCount(): number {
    return 0;
  }

  public getData(index: number): TaskItem {
    return this.originDataArray[index];
  }

  // 该方法为框架侧调用，为LazyForEach组件向其数据源处添加listener监听
  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      console.info('add listener');
      this.listeners.push(listener);
    }
  }

  // 该方法为框架侧调用，为对应的LazyForEach组件在数据源处去除listener监听
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      console.info('remove listener');
      this.listeners.splice(pos, 1);
    }
  }

  // 通知LazyForEach组件需要重载所有子组件
  notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    });
  }

  // 通知LazyForEach组件需要在index对应索引处添加子组件
  notifyDataAdd(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataAdd(index);
      // 写法2：listener.onDatasetChange([{type: DataOperationType.ADD, index: index}]);
    });
  }

  // 通知LazyForEach组件在index对应索引处数据有变化，需要重建该子组件
  notifyDataChange(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataChange(index);
      // 写法2：listener.onDatasetChange([{type: DataOperationType.CHANGE, index: index}]);
    });
  }

  // 通知LazyForEach组件需要在index对应索引处删除该子组件
  notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
      // 写法2：listener.onDatasetChange([{type: DataOperationType.DELETE, index: index}]);
    });
  }

  // 通知LazyForEach组件将from索引和to索引处的子组件进行交换
  notifyDataMove(from: number, to: number): void {
    this.listeners.forEach(listener => {
      listener.onDataMove(from, to);
      // 写法2：listener.onDatasetChange(
      //         [{type: DataOperationType.EXCHANGE, index: {start: from, end: to}}]);
    });
  }

  notifyDatasetChange(operations: DataOperation[]): void {
    this.listeners.forEach(listener => {
      listener.onDatasetChange(operations);
    });
  }
}

export class WaitTaskItemDataSource extends BasicDataSource {
  dataArray: TaskItem[] = [];
  private total: number = 0;
  private isGetedTotal: boolean = false;

  public resetTotalCount() {
    this.isGetedTotal = false;
  }

  public totalCount(): number {
    return this.dataArray.length;
  }

  public currentCount(): number {
    return this.dataArray.length;
  }

  public getData(index: number): TaskItem {
    return this.dataArray[index];
  }

  public clearData() {
    this.dataArray = [];
    this.isGetedTotal = false;
  }

  public pushData(data: TaskItem): void {
    this.dataArray.push(data);
    this.notifyDataAdd(this.dataArray.length - 1);
  }

  public addData(data: TaskItem[]): void {
    let len = this.dataArray.length;
    this.dataArray = this.dataArray.concat(data);
    this.notifyDataAdd(len);
  }

  public removeData(index: number) {
    this.dataArray.splice(index, 1);
    this.notifyDataDelete(index);
  }
}

export class SucTaskItemDataSource {
  private listeners: DataChangeListener[] = [];
  dataArray: ServerPhotoItem[] = [];

  private total: number = 0

  public setTotalCount(total: number) {
    this.total = total
  }
  public totalCount(): number {
    return this.total
  }

  public progress(currentSuccess: number, currentFailed: number) {
    return Math.floor((currentSuccess + currentFailed) / this.totalCount() * 100)
  }

  public currentCount(): number {
    return this.dataArray.length;
  }

  public getData(index: number): ServerPhotoItem {
    return this.dataArray[index];
  }

  public clearData() {
    this.dataArray.splice(0, this.dataArray.length)
    this.notifyDataReload()
  }

  public pushData(data: ServerPhotoItem): void {
    this.dataArray.push(data);
    this.notifyDataAdd(this.dataArray.length - 1);
  }

  public addData(data: ServerPhotoItem[]): void {
    let len = this.dataArray.length;
    this.dataArray = this.dataArray.concat(data);
    this.total = this.dataArray.length;
    this.notifyDataAdd(len);
  }

  public removeData(index: number) {
    this.dataArray.splice(index, 1);
    this.notifyDataDelete(index);
  }

  // 该方法为框架侧调用，为LazyForEach组件向其数据源处添加listener监听
  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  // 该方法为框架侧调用，为对应的LazyForEach组件在数据源处去除listener监听
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  // 通知LazyForEach组件需要重载所有子组件
  notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    });
  }

  // 通知LazyForEach组件需要在index对应索引处添加子组件
  notifyDataAdd(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataAdd(index);
      // 写法2：listener.onDatasetChange([{type: DataOperationType.ADD, index: index}]);
    });
  }

  // 通知LazyForEach组件在index对应索引处数据有变化，需要重建该子组件
  notifyDataChange(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataChange(index);
      // 写法2：listener.onDatasetChange([{type: DataOperationType.CHANGE, index: index}]);
    });
  }

  // 通知LazyForEach组件需要在index对应索引处删除该子组件
  notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
      // 写法2：listener.onDatasetChange([{type: DataOperationType.DELETE, index: index}]);
    });
  }

  // 通知LazyForEach组件将from索引和to索引处的子组件进行交换
  notifyDataMove(from: number, to: number): void {
    this.listeners.forEach(listener => {
      listener.onDataMove(from, to);
      // 写法2：listener.onDatasetChange(
      //         [{type: DataOperationType.EXCHANGE, index: {start: from, end: to}}]);
    });
  }

  notifyDatasetChange(operations: DataOperation[]): void {
    this.listeners.forEach(listener => {
      listener.onDatasetChange(operations);
    });
  }
}