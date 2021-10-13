INSERT INTO sessions
  (session_id, user_id, ip_address, country, user_agent, username,START,"end", referrer)
  SELECT session_id,
         max(user_id),
         max(ip_address),
         max(country),
         max(user_agent),
         max(username),
         min(TIME),
         max(TIME),
         max(referrer)
  FROM EVENTS
  WHERE TIME::date>=now()::date - interval '3 days'
  GROUP BY session_id
  ON conflict(session_id) DO UPDATE SET "end"=excluded.end;


UPDATE sessions
  SET first_session_of_user_id=(
    (SELECT count(*)
      FROM sessions AS sessions_inner
      WHERE sessions_inner.user_id=sessions.user_id
      AND sessions_inner.start<sessions.start)=0
  )
  WHERE first_session_of_user_id IS NULL;
  
  
  UPDATE sessions
  SET first_session_of_ip_address=(
    (
      SELECT count(*)
      FROM sessions AS sessions_inner
      WHERE sessions_inner.ip_address=sessions.ip_address
      AND sessions_inner.start<sessions.start
    )=0
  )
  WHERE first_session_of_ip_address IS NULL;


INSERT INTO visits (user_id, username, "date", country, user_agent, duration, first_visit_of_user_id, first_visit_of_ip_address, referrer)
  SELECT user_id,
         Max(username),
         START::date,
         max(country),
         max(user_agent),
         sum(duration),
         bool_or(first_session_of_user_id),
         bool_or(first_session_of_ip_address),
         max(referrer)
  FROM sessions
  WHERE START::date>=now()::date - interval '3 days'
  GROUP BY (user_id,start::date)
  ON CONFLICT ON CONSTRAINT visits_user_id_date_key DO UPDATE SET duration=excluded.duration;
