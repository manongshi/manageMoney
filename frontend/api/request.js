const BASE_URL = (import.meta.env && import.meta.env.VITE_API_BASE_URL) || 'http://127.0.0.1:8000'

export function request(options) {
  const token = uni.getStorageSync('token')
  return new Promise((resolve, reject) => {
    uni.request({
      url: `${BASE_URL}${options.url}`,
      method: options.method || 'GET',
      data: options.data || {},
      header: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(options.header || {})
      },
      success(res) {
        const body = res.data || {}
        if (res.statusCode === 401) {
          uni.removeStorageSync('token')
        }
        if (body.code === 200) {
          resolve(body.data)
          return
        }
        reject(new Error(body.msg || '请求失败'))
      },
      fail(err) {
        reject(new Error(err.errMsg || '网络异常'))
      }
    })
  })
}
