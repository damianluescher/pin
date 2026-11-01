// Invented numbers and names in the shape of Money's data. Nothing here comes from his real data.
(() => {
  let n = 0;
  const I = (list, name, amount, status, note = '', o = {}) => ({ id: 'x' + ++n, list, name, amount, cur: 'CHF', status, note, logo: '', due: '', done: false, ...o });
  window.MONEY_INVENTED = {
    version: 1, base: { comingBack: 640, billsPaid: 310 }, ordered: {},
    trips: { ny: { name: 'Made-up trip', dates: '3 to 9 March', share: true } },
    items: [
      I('have', 'Everyday account', 2150.4, 'OK', 'Made-up balance', { logo: 'neon' }),
      I('have', 'Savings account', 8000, 'OK', 'Made-up balance', { logo: 'ubs' }),
      I('have', 'Index fund', 3200, 'OK', '3200 USD, made up', { cur: 'USD', logo: 'etoro' }),
      I('have', 'Euro cash', 60, 'OK', '60 EUR', { cur: 'EUR' }),
      I('have', 'Travel card', null, 'CHECK', 'How much is on it?', { logo: 'revolut' }),
      I('have', 'Old account', 45, 'CHECK', 'Still open or closed?'),
      I('coming', 'Anna', 120, 'OK', 'Concert tickets', { due: '12 Dec' }),
      I('coming', 'Ben', 75.5, 'CHECK', 'Dinner, not asked yet'),
      I('coming', 'Jacket return', 180, 'OK', 'Return in store with receipt', { due: '20 Dec', logo: 'cos' }),
      I('coming', 'Carla', 300, 'OK', 'Camera share', { due: '5 Jan' }),
      I('maybe', 'Tax refund', 150, 'CHECK', 'If the form goes through'),
      I('maybe', 'Train voucher', 40, 'OK', 'For the next trip', { logo: 'swiss' }),
      I('could', 'Bakery, product film', 900, 'OK', 'Not agreed yet'),
      I('could', 'Part-time wage', 1400, 'CHECK', 'Per month, confirm', { monthly: true }),
      I('sell', 'Old phone', 220, 'OK', 'Estimate 180 to 260'),
      I('sell', 'Old laptop', 350, 'CHECK', 'Estimate 300 to 400'),
      I('sell', 'Spare lens', 280, 'OK', 'Rough guess', { logo: 'tamron' }),
      I('bills', 'Income tax', 1800, 'CHECK', 'Rough guess 1500 to 2100', { logo: 'zh' }),
      I('bills', 'Pension payment', 950, 'CHECK', 'The office sets the real amount', { logo: 'sva' }),
      I('bills', 'Health insurance', 310.25, 'OK', 'November', { due: '30 Nov', logo: 'atupri' }),
      I('bills', 'Phone repair', 89, 'OK', '', { due: '8 Dec' }),
      I('bills', 'Photo prints', 24.5, 'CHECK', 'Was it paid already?', { logo: 'fotopost' }),
      I('bills', 'Dentist', null, 'CHECK', 'Invoice not here yet'),
      I('monthly', 'Phone plan', 29, 'OK', '', { logo: 'salt' }),
      I('monthly', 'Fitness', 45, 'OK', '', { logo: 'whoop' }),
      I('monthly', 'Music', 12.9, 'CHECK', 'Still using it?'),
      I('vac', 'Flight', 480, 'OK', 'Made up', { group: 'fixed', trip: 'ny', done: true }),
      I('vac', 'Voucher', 100, 'OK', 'Made up', { group: 'credit', trip: 'ny', done: true }),
      I('vac', 'Food', 300, 'OK', 'Made up', { group: 'spend', trip: 'ny', done: true }),
      I('vac', 'Harbour Hotel', 620, 'OK', 'Made up', { group: 'brooklyn', trip: 'ny', nights: 4, people: 2, done: true, meta: '8.4 · By the water' }),
      I('vac', 'Station Inn', 700, 'OK', 'Made up', { group: 'manhattan', trip: 'ny', nights: 5, people: 1, done: true, meta: '8.1 · Near the station' }),
    ],
  };
})();
