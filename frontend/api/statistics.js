import { request } from './request'

export function getDashboard() {
  return request({
    url: '/statistics/dashboard'
  })
}

export function getDayStats(date) {
  return request({
    url: `/statistics/day${date ? `?date=${date}` : ''}`
  })
}

export function getMonthStats(month) {
  return request({
    url: `/statistics/month${month ? `?month=${month}` : ''}`
  })
}

export function getCategoryStats(params = {}) {
  const query = new URLSearchParams(params).toString()
  return request({
    url: `/statistics/category${query ? `?${query}` : ''}`
  })
}

export function getTrendStats(range = '7d') {
  return request({
    url: `/statistics/trend?range=${range}`
  })
}
