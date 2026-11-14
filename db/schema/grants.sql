create user inspector 
with password 'NetoSQL2025';

grant all privileges
on schema buldakov_food
to inspector;

grant all privileges
on all tables in schema buldakov_food
to inspector;

grant all privileges
on all sequences in schema buldakov_food
to inspector;

grant all privileges
on all routines in schema buldakov_food
to inspector;

grant usage on schema information_schema to inspector;
grant usage on schema pg_catalog to inspector;

grant usage on schema exts to inspector;

grant execute on function exts.uuid_generate_v4() to inspector;