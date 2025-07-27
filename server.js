const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const mongoose = require('mongoose');
const redis = require('redis');
const cors = require('cors');
require('dotenv').config();

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Middleware
app.use(cors());
app.use(express.json());

// MongoDB Connection
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/swifttracker', {
  useNewUrlParser: true,
  useUnifiedTopology: true
});

// Redis Client for caching
const redisClient = redis.createClient({
  host: process.env.REDIS_HOST || '127.0.0.1',
  port: process.env.REDIS_PORT || 6379
});

redisClient.on('error', (err) => {
  console.error('Redis error:', err);
});

// Tracking Data Schema
const trackingSchema = new mongoose.Schema({
  deviceId: String,
  timestamp: { type: Date, default: Date.now },
  location: {
    lat: Number,
    lng: Number
  },
  speed: Number,
  battery: Number,
  status: String
});

const TrackingData = mongoose.model('TrackingData', trackingSchema);

// Analytics Schema
const analyticsSchema = new mongoose.Schema({
  date: Date,
  totalDevices: Number,
  activeDevices: Number,
  averageSpeed: Number,
  totalDistance: Number
});

const Analytics = mongoose.model('Analytics', analyticsSchema);

// Routes
app.get('/api/devices', async (req, res) => {
  try {
    const devices = await TrackingData.distinct('deviceId');
    res.json(devices);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/device/:id/history', async (req, res) => {
  try {
    const history = await TrackingData.find({ deviceId: req.params.id })
      .sort({ timestamp: -1 })
      .limit(100);
    res.json(history);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/analytics', async (req, res) => {
  try {
    const analytics = await Analytics.find()
      .sort({ date: -1 })
      .limit(30);
    res.json(analytics);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// WebSocket Connection
io.on('connection', (socket) => {
  console.log('New client connected:', socket.id);
  
  // Join device room
  socket.on('joinDevice', (deviceId) => {
    socket.join(deviceId);
    console.log(`Device ${deviceId} joined`);
  });
  
  // Send tracking data
  socket.on('trackingData', async (data) => {
    try {
      const trackingEntry = new TrackingData(data);
      await trackingEntry.save();
      
      // Emit to device room
      io.to(data.deviceId).emit('liveUpdate', data);
      
      // Emit to all clients for dashboard
      io.emit('dashboardUpdate', data);
      
      // Cache latest data in Redis
      redisClient.setex(`latest:${data.deviceId}`, 3600, JSON.stringify(data));
    } catch (error) {
      console.error('Error saving tracking data:', error);
    }
  });
  
  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
