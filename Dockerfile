# سيرفر Dart للأونلاين. البناء من جذر المشروع:  docker build -t domino-server .
FROM dart:stable AS build
WORKDIR /app
COPY lib/core ./lib/core
COPY server ./server
WORKDIR /app/server
RUN dart pub get && dart compile exe bin/server.dart -o /app/server_bin

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/server_bin /app/server
ENV PORT=8080
EXPOSE 8080
CMD ["/app/server"]
