For hello world: make GET request to
http://lindboard-staging.azurewebsites.net/api/esp/ping

Respones contains actions battery needs to do.
Battery should send new request confirmint that the action has been done

# Concerns

Should have system to report errors to server. Both network errors (when no
response was received for example), and errors in response content.

