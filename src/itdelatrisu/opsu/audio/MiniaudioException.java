package itdelatrisu.opsu.audio;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

public final class MiniaudioException extends RuntimeException {
    private static final Map<Integer, String> RESULT_NAMES;

    static {
        Map<Integer, String> resultNames = new HashMap<>();

        resultNames.put(0, "MA_SUCCESS");
        resultNames.put(-1, "MA_ERROR");  /* A generic error. */
        resultNames.put(-2, "MA_INVALID_ARGS");
        resultNames.put(-3, "MA_INVALID_OPERATION");
        resultNames.put(-4, "MA_OUT_OF_MEMORY");
        resultNames.put(-5, "MA_OUT_OF_RANGE");
        resultNames.put(-6, "MA_ACCESS_DENIED");
        resultNames.put(-7, "MA_DOES_NOT_EXIST");
        resultNames.put(-8, "MA_ALREADY_EXISTS");
        resultNames.put(-9, "MA_TOO_MANY_OPEN_FILES");
        resultNames.put(-10, "MA_INVALID_FILE");
        resultNames.put(-11, "MA_TOO_BIG");
        resultNames.put(-12, "MA_PATH_TOO_LONG");
        resultNames.put(-13, "MA_NAME_TOO_LONG");
        resultNames.put(-14, "MA_NOT_DIRECTORY");
        resultNames.put(-15, "MA_IS_DIRECTORY");
        resultNames.put(-16, "MA_DIRECTORY_NOT_EMPTY");
        resultNames.put(-17, "MA_AT_END");
        resultNames.put(-18, "MA_NO_SPACE");
        resultNames.put(-19, "MA_BUSY");
        resultNames.put(-20, "MA_IO_ERROR");
        resultNames.put(-21, "MA_INTERRUPT");
        resultNames.put(-22, "MA_UNAVAILABLE");
        resultNames.put(-23, "MA_ALREADY_IN_USE");
        resultNames.put(-24, "MA_BAD_ADDRESS");
        resultNames.put(-25, "MA_BAD_SEEK");
        resultNames.put(-26, "MA_BAD_PIPE");
        resultNames.put(-27, "MA_DEADLOCK");
        resultNames.put(-28, "MA_TOO_MANY_LINKS");
        resultNames.put(-29, "MA_NOT_IMPLEMENTED");
        resultNames.put(-30, "MA_NO_MESSAGE");
        resultNames.put(-31, "MA_BAD_MESSAGE");
        resultNames.put(-32, "MA_NO_DATA_AVAILABLE");
        resultNames.put(-33, "MA_INVALID_DATA");
        resultNames.put(-34, "MA_TIMEOUT");
        resultNames.put(-35, "MA_NO_NETWORK");
        resultNames.put(-36, "MA_NOT_UNIQUE");
        resultNames.put(-37, "MA_NOT_SOCKET");
        resultNames.put(-38, "MA_NO_ADDRESS");
        resultNames.put(-39, "MA_BAD_PROTOCOL");
        resultNames.put(-40, "MA_PROTOCOL_UNAVAILABLE");
        resultNames.put(-41, "MA_PROTOCOL_NOT_SUPPORTED");
        resultNames.put(-42, "MA_PROTOCOL_FAMILY_NOT_SUPPORTED");
        resultNames.put(-43, "MA_ADDRESS_FAMILY_NOT_SUPPORTED");
        resultNames.put(-44, "MA_SOCKET_NOT_SUPPORTED");
        resultNames.put(-45, "MA_CONNECTION_RESET");
        resultNames.put(-46, "MA_ALREADY_CONNECTED");
        resultNames.put(-47, "MA_NOT_CONNECTED");
        resultNames.put(-48, "MA_CONNECTION_REFUSED");
        resultNames.put(-49, "MA_NO_HOST");
        resultNames.put(-50, "MA_IN_PROGRESS");
        resultNames.put(-51, "MA_CANCELLED");
        resultNames.put(-52, "MA_MEMORY_ALREADY_MAPPED");

        /* General non-standard errors. */
        resultNames.put(-100, "MA_CRC_MISMATCH");

        /* General miniaudio-specific errors. */
        resultNames.put(-200, "MA_FORMAT_NOT_SUPPORTED");
        resultNames.put(-201, "MA_DEVICE_TYPE_NOT_SUPPORTED");
        resultNames.put(-202, "MA_SHARE_MODE_NOT_SUPPORTED");
        resultNames.put(-203, "MA_NO_BACKEND");
        resultNames.put(-204, "MA_NO_DEVICE");
        resultNames.put(-205, "MA_API_NOT_FOUND");
        resultNames.put(-206, "MA_INVALID_DEVICE_CONFIG");
        resultNames.put(-207, "MA_LOOP");
        resultNames.put(-208, "MA_BACKEND_NOT_ENABLED");

        /* State errors. */
        resultNames.put(-300, "MA_DEVICE_NOT_INITIALIZED");
        resultNames.put(-301, "MA_DEVICE_ALREADY_INITIALIZED");
        resultNames.put(-302, "MA_DEVICE_NOT_STARTED");
        resultNames.put(-303, "MA_DEVICE_NOT_STOPPED");

        /* Operation errors. */
        resultNames.put(-400, "MA_FAILED_TO_INIT_BACKEND");
        resultNames.put(-401, "MA_FAILED_TO_OPEN_BACKEND_DEVICE");
        resultNames.put(-402, "MA_FAILED_TO_START_BACKEND_DEVICE");
        resultNames.put(-403, "MA_FAILED_TO_STOP_BACKEND_DEVICE");

        RESULT_NAMES = Collections.unmodifiableMap(resultNames);
    }

    public MiniaudioException(int result, String message) {
        super(message + ": " + RESULT_NAMES.getOrDefault(result, "<unknown result " + result + ">"));
    }
}
