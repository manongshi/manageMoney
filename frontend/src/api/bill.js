import { request } from './request'

export function listBills(params = {}) {
  const query = new URLSearchParams(
    Object.entries(params).filter(([, value]) => value !== undefined && value !== null && value !== '')
  ).toString()
  return request({
    url: `/bill/list${query ? `?${query}` : ''}`
  })
}

export function addBill(data) {
  return request({
    url: '/bill/add',
    method: 'POST',
    data
  })
}

export function updateBill(id, data) {
  return request({
    url: `/bill/update/${id}`,
    method: 'PUT',
    data
  })
}

export function deleteBill(id) {
  return request({
    url: `/bill/delete/${id}`,
    method: 'DELETE'
  })
}
