import { defineStore } from 'pinia'
import { listBills } from '../api/bill'
import { listCategories } from '../api/category'

export const useBillStore = defineStore('bill', {
  state: () => ({
    categories: [],
    bills: [],
    total: 0
  }),
  getters: {
    expenseCategories: (state) => state.categories.filter((item) => item.type === 'expense'),
    incomeCategories: (state) => state.categories.filter((item) => item.type === 'income')
  },
  actions: {
    async loadCategories(type) {
      this.categories = await listCategories(type ? { type } : {})
      return this.categories
    },
    async loadBills(params = {}) {
      const data = await listBills(params)
      this.bills = data.records
      this.total = data.total
      return data
    }
  }
})
