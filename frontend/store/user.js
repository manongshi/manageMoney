import { defineStore } from 'pinia'
import { getProfile, login, logout, register } from '../api/auth'

export const useUserStore = defineStore('user', {
  state: () => ({
    token: uni.getStorageSync('token') || '',
    user: null
  }),
  getters: {
    isLoggedIn: (state) => Boolean(state.token)
  },
  actions: {
    async login(form) {
      const data = await login(form)
      this.token = data.token
      this.user = data.user
      uni.setStorageSync('token', data.token)
      return data
    },
    async register(form) {
      return register(form)
    },
    async loadProfile() {
      if (!this.token) return null
      this.user = await getProfile()
      return this.user
    },
    async logout() {
      try {
        await logout()
      } finally {
        this.token = ''
        this.user = null
        uni.removeStorageSync('token')
      }
    }
  }
})
