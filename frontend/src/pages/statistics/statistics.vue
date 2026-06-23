<template>
  <view class="page">
    <view class="section title-row">
      <view>
        <text class="page-title">统计</text>
        <text class="muted block">{{ month }} 月度概览</text>
      </view>
      <button class="small-btn" @click="loadAll">刷新</button>
    </view>

    <view class="section panel">
      <view class="field no-top">
        <text class="field-label">月份</text>
        <input v-model="month" class="input" placeholder="YYYY-MM" @confirm="loadAll" />
      </view>
      <view class="button-row">
        <button class="btn btn-secondary" @click="loadAll">查看</button>
      </view>
    </view>

    <view class="section grid-2">
      <view class="metric">
        <text class="metric-label">月收入</text>
        <text class="metric-value income">¥{{ money(monthStats.income) }}</text>
      </view>
      <view class="metric">
        <text class="metric-label">月支出</text>
        <text class="metric-value expense">¥{{ money(monthStats.expense) }}</text>
      </view>
      <view class="metric">
        <text class="metric-label">结余</text>
        <text class="metric-value">¥{{ money(monthStats.balance) }}</text>
      </view>
      <view class="metric">
        <text class="metric-label">今日结余</text>
        <text class="metric-value">¥{{ money(dayStats.balance) }}</text>
      </view>
    </view>

    <view class="section panel">
      <view class="title-row">
        <text class="section-title">支出分类</text>
        <text class="muted">饼图</text>
      </view>
      <view v-if="!categoryStats.length" class="empty">暂无支出数据</view>
      <pie-chart v-else :data="categoryStats" class="chart-gap" />
    </view>

    <view class="section panel">
      <view class="title-row">
        <text class="section-title">趋势</text>
        <picker :range="rangeNames" @change="onRangeChange">
          <view class="small-btn">{{ currentRangeName }}</view>
        </picker>
      </view>
      <line-chart :data="trendStats" class="chart-gap" />
    </view>
  </view>
</template>

<script setup>
import { computed, ref } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import PieChart from '../../components/pie-chart/pie-chart.vue'
import LineChart from '../../components/line-chart/line-chart.vue'
import { getCategoryStats, getDayStats, getMonthStats, getTrendStats } from '../../api/statistics'
import { currentDate, currentMonth } from '../../utils/date'
import { formatMoney } from '../../utils/money'
import { useUserStore } from '../../store/user'

const userStore = useUserStore()
const month = ref(currentMonth())
const range = ref('7d')
const dayStats = ref({})
const monthStats = ref({})
const categoryStats = ref([])
const trendStats = ref([])
const ranges = [
  { label: '近7天', value: '7d' },
  { label: '近30天', value: '30d' },
  { label: '近12个月', value: '12m' }
]
const rangeNames = ranges.map((item) => item.label)
const currentRangeName = computed(() => ranges.find((item) => item.value === range.value)?.label || '近7天')

function money(value) {
  return formatMoney(value)
}

async function loadAll() {
  if (!userStore.token) {
    uni.redirectTo({ url: '/pages/login/login' })
    return
  }
  try {
    const [day, monthData, categoryData, trendData] = await Promise.all([
      getDayStats(currentDate()),
      getMonthStats(month.value),
      getCategoryStats({ month: month.value, bill_type: 'expense' }),
      getTrendStats(range.value)
    ])
    dayStats.value = day
    monthStats.value = monthData
    categoryStats.value = categoryData
    trendStats.value = trendData
  } catch (error) {
    uni.showToast({ title: error.message, icon: 'none' })
  }
}

function onRangeChange(event) {
  const index = Number(event.detail.value)
  range.value = ranges[index]?.value || '7d'
  loadAll()
}

onShow(loadAll)
</script>

<style scoped>
.block {
  display: block;
  margin-top: 8rpx;
}

.section-title {
  display: block;
  min-width: 0;
  font-size: 30rpx;
  font-weight: 900;
  line-height: 1.3;
  word-break: break-word;
}

.small-btn {
  flex: 0 0 auto;
  margin: 0;
  height: 58rpx;
  line-height: 58rpx;
  padding: 0 18rpx;
  border: 1rpx solid #dce4dd;
  border-radius: 8px;
  background: #fff;
  color: #15211a;
  font-size: 24rpx;
  white-space: nowrap;
}

.chart-gap {
  margin-top: 22rpx;
}

.no-top {
  margin-top: 0;
}
</style>
