import { request } from './request'

export function parseBillText(text) {
  return request({
    url: '/ai/parse',
    method: 'POST',
    data: { text }
  })
}

export function recordBillText(text) {
  return request({
    url: '/ai/record',
    method: 'POST',
    data: { text }
  })
}
