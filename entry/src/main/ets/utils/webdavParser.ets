import { util } from "@kit.ArkTS";
import { strip } from "./tools";

// 定义 WebDAV 资源类型
export interface WebDAVResource {
  href: string;
  displayName: string;
  lastModified: string;
  creationDate: string;
  contentType: string;
  contentLength: number;
  resourceType: 'file' | 'directory';
  etag: string;
  status: string;
}

// 定义解析结果类型
export interface ParseResult {
  resources: WebDAVResource[];
  directories: WebDAVResource[];
  files: WebDAVResource[];
}

// 使用正则表达式解析（更可靠的方法）
export function parseWebDAVWithRegex(xmlContent: string): ParseResult {
  const result: ParseResult = {
    resources: [],
    directories: [],
    files: []
  };

  // 匹配每个 response 块
  const responseRegex = /<D:response>([\s\S]*?)<\/D:response>/g;
  let responseMatch:  RegExpExecArray | null;

  while ((responseMatch = responseRegex.exec(xmlContent)) !== null) {
    const responseContent = responseMatch[1];
    const resource = parseResponseBlock(responseContent);

    if (resource) {
      result.resources.push(resource);
      if (resource.resourceType === 'directory') {
        result.directories.push(resource);
      } else {
        result.files.push(resource);
      }
    }
  }

  return result;
}

// 解析单个 response 块
function parseResponseBlock(blockContent: string): WebDAVResource | null {
  try {
    const resource: Partial<WebDAVResource> = {};

    // 提取 href
    const hrefMatch = /<D:href>([\s\S]*?)<\/D:href>/.exec(blockContent);
    if (hrefMatch && hrefMatch[1]) {
      resource.href = hrefMatch[1].trim();
      let h = strip(resource.href, '/')
      if (h == "") {
       resource.displayName = ""
      } else {
        let dl = h.split('/')
        let name = dl.pop()
        resource.displayName = decodeURIComponent(name ? name : "")
      }
    } else {
      return null; // 没有 href 的响应无效
    }

    // 提取 displayname
    const displayNameMatch = /<D:displayname>([\s\S]*?)<\/D:displayname>/.exec(blockContent);
    if (displayNameMatch && displayNameMatch[1]) {
      resource.displayName = displayNameMatch[1].trim();
    }

    // 提取 lastmodified
    const lastModifiedMatch = /<D:getlastmodified>([\s\S]*?)<\/D:getlastmodified>/.exec(blockContent);
    if (lastModifiedMatch && lastModifiedMatch[1]) {
      resource.lastModified = lastModifiedMatch[1].trim();
    }

    // 提取 creationdate
    const creationDateMatch = /<D:creationdate>([\s\S]*?)<\/D:creationdate>/.exec(blockContent);
    if (creationDateMatch && creationDateMatch[1]) {
      resource.creationDate = creationDateMatch[1].trim();
    }

    // 提取 contenttype
    const contentTypeMatch = /<D:getcontenttype>([\s\S]*?)<\/D:getcontenttype>/.exec(blockContent);
    if (contentTypeMatch && contentTypeMatch[1]) {
      resource.contentType = contentTypeMatch[1].trim();
    }

    // 提取 contentlength
    const contentLengthMatch = /<D:getcontentlength>([\s\S]*?)<\/D:getcontentlength>/.exec(blockContent);
    if (contentLengthMatch && contentLengthMatch[1]) {
      resource.contentLength = parseInt(contentLengthMatch[1].trim(), 10) || 0;
    }

    // 提取 etag
    const etagMatch = /<D:getetag>([\s\S]*?)<\/D:getetag>/.exec(blockContent);
    if (etagMatch && etagMatch[1]) {
      resource.etag = etagMatch[1].trim().replace(/"/g, '');
    }

    // 提取 status
    const statusMatch = /<D:status>([\s\S]*?)<\/D:status>/.exec(blockContent);
    if (statusMatch && statusMatch[1]) {
      resource.status = statusMatch[1].trim();
    }

    // 判断资源类型（文件还是目录）
    const isCollection = /<D:collection><\/D:collection>/.test(blockContent) ||
    /<D:resourcetype>\s*<D:collection\/>\s*<\/D:resourcetype>/.test(blockContent) ||
    /<D:collection xmlns:D="DAV:"\/>/.test(blockContent);
    resource.resourceType = isCollection ? 'directory' : 'file';

    return resource as WebDAVResource;
  } catch (error) {
    console.error('解析响应块错误:', error);
    return null;
  }
}

export class WebDAVParser {
  // 解析 XML 内容
  static parse(xmlContent: string): ParseResult {
    return parseWebDAVWithRegex(xmlContent);
  }

  // 从 ArrayBuffer 解析（如果你从网络请求获取的是ArrayBuffer）
  static parseFromArrayBuffer(buffer: ArrayBuffer, encoding: string = 'utf-8'): ParseResult {
    const decoder = new util.TextDecoder();
    let uint8array = new Uint8Array(buffer)
    const xmlContent = decoder.decodeToString(uint8array);
    return WebDAVParser.parse(xmlContent);
  }

  // 按类型过滤
  static filterByType(resources: WebDAVResource[], type: 'file' | 'directory'): WebDAVResource[] {
    return resources.filter(resource => resource.resourceType === type);
  }

  // 按路径过滤
  static filterByPath(resources: WebDAVResource[], path: string): WebDAVResource[] {
    const normalizedPath = path.endsWith('/') ? path : path + '/';
    return resources.filter(resource =>
    resource.href.startsWith(normalizedPath) &&
      resource.href !== normalizedPath
    );
  }

  // 获取文件扩展名
  static getFileExtension(resource: WebDAVResource): string {
    if (resource.resourceType === 'directory') return '';

    const fileName = WebDAVParser.getFileName(resource);
    const lastDotIndex = fileName.lastIndexOf('.');
    return lastDotIndex > 0 ? fileName.substring(lastDotIndex + 1) : '';
  }

  // 获取文件名
  static getFileName(resource: WebDAVResource): string {
    const parts = resource.href.split('/').filter(part => part);
    return parts[parts.length - 1] || resource.displayName || '';
  }
}