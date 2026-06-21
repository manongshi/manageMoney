import { request } from './request'

export function parseBillText(text) {
  return request({
    url: '/ai/parse',
    method: 'POST',
    data: { text }
  })
}
