export function formatMoney(value) {
  const number = Number(value || 0)
  return number.toFixed(2)
}

export function signedMoney(bill) {
  const prefix = bill.bill_type === 'income' ? '+' : '-'
  return `${prefix}${formatMoney(bill.amount)}`
}
