import { request } from './request'

export function register(data) {
  return request({
    url: '/auth/register',
    method: 'POST',
    data
  })
}

export function login(data) {
  return request({
    url: '/auth/login',
    method: 'POST',
    data
  })
}

export function getProfile() {
  return request({
    url: '/user/me'
  })
}

export function changePassword(data) {
  return request({
    url: '/auth/change-password',
    method: 'POST',
    data
  })
}

export function logout() {
  return request({
    url: '/auth/logout',
    method: 'POST'
  })
}
