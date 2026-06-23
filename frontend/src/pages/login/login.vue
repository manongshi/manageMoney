<template>
  <view class="login-page">
    <view class="brand">
      <text class="brand-mark">¥</text>
      <text class="brand-title">AI智能记账</text>
      <text class="brand-subtitle">把每一笔收支变成清楚的日常记录</text>
    </view>

    <view class="panel login-panel">
      <view class="segmented">
        <view :class="['segment', mode === 'login' ? 'active-expense' : '']" @click="mode = 'login'">登录</view>
        <view :class="['segment', mode === 'register' ? 'active-income' : '']" @click="mode = 'register'">注册</view>
      </view>

      <view class="field">
        <text class="field-label">手机号</text>
        <input v-model="form.username" class="input" placeholder="请输入手机号" />
      </view>
      <view v-if="mode === 'register'" class="field">
        <text class="field-label">昵称</text>
        <input v-model="form.nickname" class="input" placeholder="请输入昵称" />
      </view>
      <view class="field">
        <text class="field-label">密码</text>
        <input v-model="form.password" class="input" password placeholder="至少 6 位" />
      </view>

      <view class="button-row">
        <button class="btn btn-primary" :disabled="loading" @click="submit">
          {{ loading ? '处理中' : mode === 'login' ? '登录' : '注册并登录' }}
        </button>
      </view>
    </view>
  </view>
</template>

<script setup>
import { reactive, ref } from 'vue'
import { useUserStore } from '../../store/user'

const userStore = useUserStore()
const mode = ref('login')
const loading = ref(false)
const form = reactive({
  username: '',
  nickname: '',
  password: ''
})

async function submit() {
  if (!form.username || !form.password) {
    uni.showToast({ title: '请填写手机号和密码', icon: 'none' })
    return
  }
  loading.value = true
  try {
    if (mode.value === 'register') {
      await userStore.register({
        username: form.username,
        password: form.password,
        nickname: form.nickname || form.username
      })
    }
    await userStore.login({ username: form.username, password: form.password })
    uni.switchTab({ url: '/pages/index/index' })
  } catch (error) {
    uni.showToast({ title: error.message, icon: 'none' })
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-page {
  min-height: 100vh;
  width: 100%;
  max-width: 750rpx;
  margin: 0 auto;
  padding: 56rpx 28rpx calc(44rpx + env(safe-area-inset-bottom));
  box-sizing: border-box;
  background:
    linear-gradient(140deg, rgba(31, 111, 120, 0.16), transparent 34%),
    linear-gradient(320deg, rgba(22, 128, 60, 0.13), transparent 42%),
    #f5f7f4;
}

.brand {
  display: flex;
  flex-direction: column;
  gap: 14rpx;
  margin: 54rpx 0 40rpx;
  min-width: 0;
}

.brand-mark {
  width: 84rpx;
  height: 84rpx;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #15211a;
  color: #fff;
  font-size: 48rpx;
  font-weight: 900;
}

.brand-title {
  font-size: 50rpx;
  font-weight: 900;
  letter-spacing: 0;
  line-height: 1.16;
  word-break: break-word;
}

.brand-subtitle {
  max-width: 580rpx;
  color: #69746d;
  font-size: 28rpx;
  line-height: 1.45;
  word-break: break-word;
}

.login-panel {
  margin-top: 24rpx;
}
</style>
