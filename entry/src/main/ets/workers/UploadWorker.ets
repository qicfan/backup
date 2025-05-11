import { ErrorEvent, MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS';
import { UploadItemSendable } from '../models/UploadItemSendable';
import { fileIo } from '@kit.CoreFileKit';
import { common, sendableContextManager } from '@kit.AbilityKit';
import { BusinessError, emitter, request } from '@kit.BasicServicesKit';
import { deleteFile, getMimeTypeFromExtension, strip } from '../utils/tools';
import { RequestReturn, WebDav } from '../utils/webdav';
import { ServerConfig } from '../models/Server';
import { rcp } from '@kit.RemoteCommunicationKit';
import { SERVER_AUTH_FAILED_EVENT } from '../typing';

const workerPort: ThreadWorkerGlobalScope = worker.workerPort;

/**
 * Defines the event handler to be called when the worker thread receives a message sent by the host thread.
 * The event handler is executed in the worker thread.
 *
 * @param event message data
 */
workerPort.onmessage = (event: MessageEvents) => {
  // console.log(`上传线程收到消息：${JSON.stringify(event.data)}`)
  doTask(event.data).then((rs) => {
    if (rs === "SUCCESS") {
      workerPort.postMessage({action: "FINISH", code: 200, message: "", taskItemId: event.data.taskItemId, type: event.data.type});
    } else if (rs === "FILE NOT EXISTS"){
      workerPort.postMessage({action: "FILE_NOT_EXISTS", code: 404, message: "本地临时文件不存在", taskItemId: event.data.taskItemId, type: event.data.type});
    } else {
      workerPort.postMessage({action: "ERROR", code: 0, message: event.data.message, taskItemId: event.data.taskItemId, type: event.data.type});
    }
    // workerPort.postMessage(rs);
  }).catch((err: BusinessError) => {
    workerPort.postMessage({action: "ERROR", code: err.code, message: err.message, taskItemId: event.data.taskItemId, type: event.data.type});
  })
};

/**
 * Defines the event handler to be called when the worker receives a message that cannot be deserialized.
 * The event handler is executed in the worker thread.
 *
 * @param event message data
 */
workerPort.onmessageerror = (event: MessageEvents) => {
};

/**
 * Defines the event handler to be called when an exception occurs during worker execution.
 * The event handler is executed in the worker thread.
 *
 * @param event error message
 */
workerPort.onerror = (event: ErrorEvent) => {
};

let session: rcp.Session;

async function updateSerConfig(server: string, username: string, password: string) {
  session?.close()
  session = rcp.createSession({
    baseAddress: server,
    headers: { "Accept": "text/plain,application/xml" },
    requestConfiguration: {
      transfer: {
        timeout: { connectMs: 3000 }
      },
      security: {
        serverAuthentication: {
          credential: {
            username: username,
            password: password
          },
          authenticationType: "basic"
        }
      }
    }
  });
}

async function mkRemotePath(uploadItem: UploadItemSendable): Promise<boolean> {
  let remoteUri: string = uploadItem.remoteUri;
  remoteUri = remoteUri.replace(uploadItem.serverBaseUrl, "").replace(uploadItem.backupRootPath, "");
  const dirList: string[] = remoteUri.split('/').filter(part => part.length > 0);
  dirList.pop();
  // 检查路径是否已经存在
  let currentPath: string = strip(uploadItem.backupRootPath, '/');
  const rs = await colExists(currentPath + '/' + dirList.join('/'))
  if (rs) return true;
  for (let dir of dirList) {
    // 创建目录
    currentPath += `/${dir}`;
    // console.log(`创建远程目录: ${currentPath}`);
    const rr = await mkDir(currentPath);
    if ((rr.statusCode >= 200 && rr.statusCode < 300) || rr.statusCode == 405) {
      continue
    } else {
      // 创建目录失败
      console.error(`创建目录失败：${currentPath}`);
      return false;
    }
  }
  // console.log(`创建远程目录: ${currentPath}成功`)
  return true;
}



// 发送请求
async function rcpRequest(req: rcp.Request) {
  const requestReturn: RequestReturn = new RequestReturn();
  try {
    const resp = await session?.fetch(req);
    if (resp === undefined) {
      requestReturn.statusCode = 500;
      requestReturn.success = false;
      requestReturn.message = "请求失败"
      return requestReturn;
    }
    // console.log(JSON.stringify(resp.headers));
    requestReturn.statusCode = resp.statusCode;
    requestReturn.headers = resp.headers;
    if (resp.statusCode === 401) {
      requestReturn.message = "用户名密码不正确"
      requestReturn.success = false;
      // 触发登录失败事件
      emitter.emit(SERVER_AUTH_FAILED_EVENT);
    }

    if (resp.statusCode === 500) {
      requestReturn.message = "服务器内部错误，请检查服务器是否正常。"
      requestReturn.success = false;
    }
    if (resp.statusCode === 407) {
      requestReturn.message = "目录不存在，请先创建目录"
      requestReturn.success = false;
    }
    if (resp.statusCode === 507) {
      requestReturn.message = "服务器存储空间不足"
      requestReturn.success = false;
    }
    if (requestReturn.statusCode >= 200 && requestReturn.statusCode < 300) {
      // 正常
      requestReturn.statusCode = 200
      requestReturn.body = resp.toString() ?? "";
      requestReturn.success = true;
    } else {
      requestReturn.success = false;
    }
  } catch (err) {
    requestReturn.statusCode = 500
    requestReturn.success = false;
    if (err.code === 1007900028) {
      requestReturn.message = "服务器超时，请检查服务器地址或端口是否正确"
    } else {
      requestReturn.message = "连接失败，请检查本机网络或者联系作者，错误码：" + err.code + ", 错误：" + err.message
    }
  }
  return requestReturn;
}

// 是否存在
async function fileExists(path: string, size: number) {
  // console.log(`查询${path}是否存在`)
  const req = new rcp.Request(path, "HEAD");
  const rr = await rcpRequest(req);
  // 不存在
  if (!rr.success) {
    // console.log(`文件请求不成功，code: ${rr.statusCode}, msg: ${rr.message}`)
    return 0;
  }
  let remoteSize: number = 0;
  let remoteSizeArr: string | string[] | undefined = rr.headers['content-length'];
  if (remoteSizeArr === undefined) {
    remoteSize = 0;
  } else if (typeof remoteSizeArr !== 'string') {
    remoteSize = parseInt(remoteSizeArr[0]);
  } else {
    remoteSize = parseInt(remoteSizeArr)
  }
  // console.log(`文件存在，比较大小是否一致, ${remoteSize}=>${size}`)
  if (remoteSize == size) {
    return 1
  } else {
    return 2;
  }
}

// 是否文件夹存在
async function colExists(path: string) {
  if (!path.endsWith('/')) {
    path = path + '/';
  }
  // console.log(`查询${path}是否存在`)
  const req = new rcp.Request(path, "HEAD");
  const rr = await rcpRequest(req);
  return rr.success;
}

// 创建目录
async function mkDir(path: string) {
  if (!path.endsWith('/')) {
    path = path + '/';
  }
  const req = new rcp.Request(path, "MKCOL");
  return await rcpRequest(req);
}

// 删除文件
async function rcpDelete(path: string) {
  const req = new rcp.Request(path, "DELETE");
  return await rcpRequest(req);
}

/**
 * 1。 检查文件是否存在，不存在则给主线程报错，主线程将该文件重新处理后放入队列继续
 * 2. 上传文件
 * 3. 上传文件过程中更新进度（修改数据库）
 * 4. 上传完成后删除临时文件
 * 5. 修改数据库状态
 */
function doTask(uploadItem: UploadItemSendable): Promise<string> {
  return new Promise(async (resolve, reject) => {
    const context: common.Context = sendableContextManager.convertToContext(uploadItem.sendableContext);
    const filesDir: string = context.cacheDir;
    const fileUri = uploadItem.fileUri.replace(filesDir, 'internal://cache')
    // console.log(`cacheDir: ${filesDir}, fileUri: ${uploadItem.fileUri}=>${fileUri}`);
    updateSerConfig(uploadItem.serverBaseUrl, uploadItem.serverUsername, uploadItem.serverPassword);
    try {
      const mkRP = await mkRemotePath(uploadItem);
      if (!mkRP) {
        return resolve("CREATE REMOTE PATH FAIL")
      }
      // 检查文件是否已存在
      let existsRR: number = await fileExists(uploadItem.remoteUri, uploadItem.fileSize);
      if (existsRR === 2) {
        // console.log(`${uploadItem.remoteUri}在服务器上存在，但是大小和本地不同，删除服务端文件。`)
        // 存在，不一致，删除远程文件
        await rcpDelete(uploadItem.remoteUri)
        existsRR = 0;
      }
      if (existsRR === 1) {
        // 已经上传完成
        // console.log(`服务器上存在${uploadItem.remoteUri}，直接返回成功`)
        return resolve("SUCCESS");
      }
    } catch (e) {
      console.error(`rcp请求报错：${e.code}, ${e.message}`)
    }
    // 上传任务配置项
    const files: Array<request.File> = [{ filename: uploadItem.name, name: 'file', uri: fileUri, type: getMimeTypeFromExtension(uploadItem.fileUri) }]
    const uploadConfig: request.UploadConfig = {
      url: uploadItem.remoteUri,
      header: {'Authorization': 'Basic ' + uploadItem.auth},
      method: 'PUT', files: files, data: []
    }
    try {
      const uploadTask: request.UploadTask = await request.uploadFile(context, uploadConfig);
      uploadTask.on('complete', () => {
        // 删除文件
        deleteFile(uploadItem.fileUri);
        uploadTask.delete().then()
        return resolve("SUCCESS")
      });
      uploadTask.on('fail', (taskStates: Array<request.TaskState>) => {
        // 删除文件
        deleteFile(uploadItem.fileUri);
        uploadTask.delete().then()
        console.info("upOnFail taskState:" + JSON.stringify(taskStates[0]));
        let err: BusinessError = {code: taskStates[0].responseCode, message: taskStates[0].message, name: "错误"};
        reject(err);
      });
      uploadTask.on("progress", (uploadedSize: number) => {
        // 更新已上传进度
        workerPort.postMessage({action: "UPDATE_PROGRESS", code: 200, message: "", uploadedSize: uploadedSize, taskItemId: uploadItem.taskItemId})
      })
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      console.error(`创建上传任务失败： ${uploadItem.fileUri} => ${uploadItem.remoteUri}, code is ${err.code}, message is ${err.message}`);
      reject(error);
    }
  })
}

