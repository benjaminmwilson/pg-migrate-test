
import {createDb, migrate, Config, BaseDBConfig, CreateDBConfig, MigrateDBConfig} from 'postgres-migrations';

const databaseName = 'test-migrations-db';

const baseDbConfig:BaseDBConfig = {
  user: "bmwilson",
  password: "",
  host: "bens-mac-mini",
  port: 5432,
};

const createDbConfig:CreateDBConfig = {
  ...baseDbConfig,
  defaultDatabase: "postgres", // optional, default: "postgres"
};

const migrateDbConfig:MigrateDBConfig = {
  ...baseDbConfig,
  database: databaseName
};

const config:Config = {
  logger: (msg) => console.log(msg)
};


createDb(databaseName, createDbConfig, config)
  .then(() => migrate(migrateDbConfig, "migrations", config))
  .then(() => {
    console.log('database ready');
  })
  .catch((err:any) => {
    console.log(err)
  });

