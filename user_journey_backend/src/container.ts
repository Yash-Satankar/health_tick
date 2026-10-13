import { Router } from 'express';
import type { Database } from './db/kysely.js';
import { defaultRng, type Rng } from './lib/rng.js';
import { userContext } from './middleware/userContext.js';
import { createAppConfigController } from './modules/app-config/app-config.controller.js';
import { AppConfigRepository } from './modules/app-config/app-config.repository.js';
import { appConfigRoutes } from './modules/app-config/app-config.routes.js';
import { AppConfigService } from './modules/app-config/app-config.service.js';
import { createAttemptsController } from './modules/attempts/attempts.controller.js';
import { AttemptsRepository } from './modules/attempts/attempts.repository.js';
import { attemptsRoutes } from './modules/attempts/attempts.routes.js';
import { AttemptsService } from './modules/attempts/attempts.service.js';
import { createEventsController } from './modules/events/events.controller.js';
import { eventsRoutes } from './modules/events/events.routes.js';
import type { EventsHub } from './modules/events/events.service.js';
import { createFeedbackController } from './modules/feedback/feedback.controller.js';
import { FeedbackRepository } from './modules/feedback/feedback.repository.js';
import { feedbackRoutes } from './modules/feedback/feedback.routes.js';
import { FeedbackService } from './modules/feedback/feedback.service.js';
import { createHomeController } from './modules/home/home.controller.js';
import { HomeRepository } from './modules/home/home.repository.js';
import { homeRoutes } from './modules/home/home.routes.js';
import { HomeService } from './modules/home/home.service.js';
import { createJourneyController } from './modules/journey/journey.controller.js';
import { JourneyRepository } from './modules/journey/journey.repository.js';
import { journeyRoutes } from './modules/journey/journey.routes.js';
import { JourneyService } from './modules/journey/journey.service.js';
import { createLessonsController } from './modules/lessons/lessons.controller.js';
import { LessonsRepository } from './modules/lessons/lessons.repository.js';
import { lessonsRoutes } from './modules/lessons/lessons.routes.js';
import { LessonsService } from './modules/lessons/lessons.service.js';
import { createSavedController } from './modules/saved/saved.controller.js';
import { SavedRepository } from './modules/saved/saved.repository.js';
import { savedRoutes } from './modules/saved/saved.routes.js';
import { SavedService } from './modules/saved/saved.service.js';
import { createSearchController } from './modules/search/search.controller.js';
import { SearchRepository } from './modules/search/search.repository.js';
import { searchRoutes } from './modules/search/search.routes.js';
import { SearchService } from './modules/search/search.service.js';

export interface ContainerOptions {
  db: Database;
  timeZone: string;
  eventsHub: EventsHub;
  rng?: Rng;
  now?: () => Date;
}

/** Wires repositories → services → controllers → routes. Everything under /api/v1 requires X-User-Id. */
export function createApiRouter(options: ContainerOptions): Router {
  const { db } = options;
  const journey = new JourneyService(new JourneyRepository(db));

  const router = Router();
  router.use(userContext(db));
  router.use(appConfigRoutes(createAppConfigController(new AppConfigService(new AppConfigRepository(db)))));
  router.use(
    homeRoutes(
      createHomeController(new HomeService(new HomeRepository(db), journey, options.timeZone, options.now)),
    ),
  );
  router.use(journeyRoutes(createJourneyController(journey)));
  router.use(searchRoutes(createSearchController(new SearchService(new SearchRepository(db), journey))));
  router.use(lessonsRoutes(createLessonsController(new LessonsService(new LessonsRepository(db), journey))));
  router.use(
    attemptsRoutes(
      createAttemptsController(
        new AttemptsService(db, new AttemptsRepository(), journey, options.rng ?? defaultRng),
      ),
    ),
  );
  router.use(savedRoutes(createSavedController(new SavedService(new SavedRepository(db), journey))));
  router.use(
    feedbackRoutes(createFeedbackController(new FeedbackService(new FeedbackRepository(db), journey))),
  );
  router.use(eventsRoutes(createEventsController(options.eventsHub)));
  return router;
}
