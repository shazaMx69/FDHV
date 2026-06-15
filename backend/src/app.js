import express from 'express'
import cors from 'cors'
import helmet from 'helmet'
import morgan from 'morgan'
import { appConfig } from './config/env.js'
import { authMiddleware } from './middlewares/authMiddleware.js'
import familiesRouter from './routes/families.js'
import { invitationsRouter } from './routes/invitations.js'
import memoriesRouter from './routes/memories.js'
import treeRouter from './routes/familyTree.js'

export function createApp () {
  const app = express()

  app.use(
    helmet({
      crossOriginResourcePolicy: { policy: 'cross-origin' }
    })
  )
  app.use(
    cors({
      origin: true,
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
    })
  )
  app.use(express.json({ limit: '10mb' }))
  app.use(morgan('dev'))

  app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() })
  })

  // All API routes require authentication
  app.use('/api', authMiddleware)

  app.use('/api/families', familiesRouter)
  app.use('/api/invitations', invitationsRouter)
  app.use('/api/memories', memoriesRouter)
  app.use('/api/family-tree', treeRouter)

  // Global error handler
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    console.error('Unhandled error', err)
    res.status(500).json({ message: 'Unexpected server error' })
  })

  return app
}
