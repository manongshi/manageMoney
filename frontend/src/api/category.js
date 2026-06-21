import { request } from './request'

export function listCategories(params = {}) {
  const query = new URLSearchParams(params).toString()
  return request({
    url: `/category/list${query ? `?${query}` : ''}`
  })
}

export function addCategory(data) {
  return request({
    url: '/category/add',
    method: 'POST',
    data
  })
}

export function updateCategory(id, data) {
  return request({
    url: `/category/update/${id}`,
    method: 'PUT',
    data
  })
}

export function deleteCategory(id) {
  return request({
    url: `/category/delete/${id}`,
    method: 'DELETE'
  })
}
