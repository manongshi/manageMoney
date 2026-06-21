import { request } from './request'

export function saveBudget(data) {
  return request({
    url: '/budget/save',
    method: 'POST',
    data
  })
}

export function getBudgetInfo(month) {
  return request({
    url: `/budget/info${month ? `?month=${month}` : ''}`
  })
}
