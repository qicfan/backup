export function dateTimeFromTimestamp(timestamp: number) {
  const date = new Date(timestamp * 1000);
  const datePart = new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date).replace(/(\d+)\/(\d+)\/(\d+)/, '$1/$2/$3');

  const timePart = new Intl.DateTimeFormat('en', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  }).format(date);

  return `${datePart} ${timePart}`;
}