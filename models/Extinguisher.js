// models/Extinguisher.js

const mongoose = require('mongoose');

const extinguisherSchema = new mongoose.Schema({
  name: { type: String, required: true },
  imagePath: { type: String, default: null }, // 예: /uploads/12345.png
  isSoundOn: { type: Boolean, default: false },
  isLightOn: { type: Boolean, default: false },
  owner: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true }, // 사용자 연결
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Extinguisher', extinguisherSchema);