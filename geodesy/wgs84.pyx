# distutils: language = c++
# -*- coding: utf-8 -*-

"""
    This module computes basic geometry operations on the WGS84 model of Earth
    Ellipsoid.

    See also: http://www.movable-type.co.uk/scripts/latlong-vincenty.html
       http://www.movable-type.co.uk/scripts/latlong-vincenty-direct.html

    You can pass all positions as pairs (lat, lon), vectors [lat, lon, ...], or
    in the natural order of parameters (..., lat, lon, ...).

    By default, the interface works with degrees, but a radian=True flag may be
    positioned if need be.

    All parameters may be passed as iterables or numpy arrays (faster).
    The dtype of the resulting vector is downcasted to the worst case precision
    among all input parameters.

    Please note that the formulas for Vincenti method are iterative and can
    therefore not be vectorised.

"""


import numpy as np

cimport numpy as cnp
cimport cython
cimport cpython

from c_geodesy cimport\
    wgs84_distance, wgs84_distance_vec_d,\
    wgs84_destination

cdef double radians = np.arccos(-1) / 180


@cython.boundscheck(False) # I will be reasonable, I promise
@cython.wraparound (False) # no negative indices
cdef distance_bearing(p1, p2, p3=None, p4=None, radian=False):
    cdef long length = 0, i = 0
    cdef double d = 0, b1 = 0, b2 = 0, lat1, lon1, lat2, lon2

    cdef cnp.ndarray[cnp.float64_t, ndim=1] lat1_64, lon1_64, lat2_64, lon2_64
    cdef cnp.ndarray[cnp.float64_t, ndim=1] d_64, b1_64, b2_64

    cdef double* pt_lat1_64
    cdef double* pt_lon1_64
    cdef double* pt_lat2_64
    cdef double* pt_lon2_64
    cdef double* pt_d_64
    cdef double* pt_b1_64
    cdef double* pt_b2_64

    cdef object item1, item2

    assert ((p3 is None) == (p4 is None)),\
        "wrong number of arguments: p3 and p4 must be provided together"

    if p3 is None:

        if (not cpython.PySequence_Check(p1)):
            raise TypeError("p1 must be a (possibly iterable of) pair of float")
        if (not cpython.PySequence_Check(p2)):
            raise TypeError("p2 must be a (possibly iterable of) pair of float")

        length = len(p1)
        if (length != len(p2)):
            raise IndexError("p1 and p2 must be of same length")

        # That would be a unique call
        if length > 1 and not cpython.PySequence_Check(p1[0]):

            lat1 = p1[0]
            lon1 = p1[1]
            lat2 = p2[0]
            lon2 = p2[1]

            if not radian:
                lat1 *= radians
                lon1 *= radians
                lat2 *= radians
                lon2 *= radians

            wgs84_distance(lat1, lon1, lat2, lon2, d, b1, b2)

            if not radian:
                b1 /= radians
                b2 /= radians

            return d, b1, b2

        # That would be only double precision
        else:
            lat1_64 = np.empty(length, dtype=np.float64)
            lat2_64 = np.empty(length, dtype=np.float64)
            lon1_64 = np.empty(length, dtype=np.float64)
            lon2_64 = np.empty(length, dtype=np.float64)

            d_64 = np.empty(length, np.float64)
            b1_64 = np.empty(length, np.float64)
            b2_64 = np.empty(length, np.float64)

            pt_lat1_64 = <double*> cnp.PyArray_DATA(lat1_64)
            pt_lon1_64 = <double*> cnp.PyArray_DATA(lon1_64)
            pt_lat2_64 = <double*> cnp.PyArray_DATA(lat2_64)
            pt_lon2_64 = <double*> cnp.PyArray_DATA(lon2_64)

            pt_d_64 = <double*> cnp.PyArray_DATA(d_64)
            pt_b1_64 = <double*> cnp.PyArray_DATA(b1_64)
            pt_b2_64 = <double*> cnp.PyArray_DATA(b2_64)

            for i in range(length):
                item1 = cpython.PySequence_ITEM(p1, i)
                pt_lat1_64[i] = item1[0]
                pt_lon1_64[i] = item1[1]

                item2 = cpython.PySequence_ITEM(p2, i)
                pt_lat2_64[i] = item2[0]
                pt_lon2_64[i] = item2[1]

                if not radian:
                    pt_lat1_64[i] *= radians
                    pt_lon1_64[i] *= radians
                    pt_lat2_64[i] *= radians
                    pt_lon2_64[i] *= radians

            wgs84_distance_vec_d(pt_lat1_64, pt_lon1_64, pt_lat2_64, pt_lon2_64,
                                 pt_d_64, pt_b1_64, pt_b2_64, length)

            if not radian:
                b1_64 /= radians
                b2_64 /= radians

            return d_64, b1_64, b2_64

    else:

        if (not cpython.PySequence_Check(p1)):

            if not radian:
                p1 *= radians
                p2 *= radians
                p3 *= radians
                p4 *= radians

            wgs84_distance(p1, p2, p3, p4, d, b1, b2)

            if not radian:
                b1 /= radians
                b2 /= radians

            return d, b1, b2

        if (not cpython.PySequence_Check(p2)):
            raise TypeError("p2 must be an iterable of float")
        if (not cpython.PySequence_Check(p3)):
            raise TypeError("p3 must be an iterable of float")
        if (not cpython.PySequence_Check(p4)):
            raise TypeError("p4 must be an iterable of float")

        length = len(p1)
        if (length != len(p2)):
            raise IndexError("p1 and p2 must be of same length")
        if (length != len(p3)):
            raise IndexError("p1 and p3 must be of same length")
        if (length != len(p4)):
            raise IndexError("p1 and p4 must be of same length")

        dtype = [e.dtype == np.float32 for e in [p1, p2, p3, p4]
                 if type(e) is np.ndarray]

        lat1_64 = np.array(p1, dtype=np.float64)
        lon1_64 = np.array(p2, dtype=np.float64)
        lat2_64 = np.array(p3, dtype=np.float64)
        lon2_64 = np.array(p4, dtype=np.float64)

        if not radian:
            lat1_64 *= radians
            lon1_64 *= radians
            lat2_64 *= radians
            lon2_64 *= radians

        d_64 = np.empty(length, np.float64)
        b1_64 = np.empty(length, np.float64)
        b2_64 = np.empty(length, np.float64)

        pt_lat1_64 = <double*> cnp.PyArray_DATA(lat1_64)
        pt_lon1_64 = <double*> cnp.PyArray_DATA(lon1_64)
        pt_lat2_64 = <double*> cnp.PyArray_DATA(lat2_64)
        pt_lon2_64 = <double*> cnp.PyArray_DATA(lon2_64)

        pt_d_64 = <double*> cnp.PyArray_DATA(d_64)
        pt_b1_64 = <double*> cnp.PyArray_DATA(b1_64)
        pt_b2_64 = <double*> cnp.PyArray_DATA(b2_64)

        wgs84_distance_vec_d(pt_lat1_64, pt_lon1_64, pt_lat2_64, pt_lon2_64,
                             pt_d_64, pt_b1_64, pt_b2_64, length)

        if not radian:
            b1_64 /= radians
            b2_64 /= radians

        return d_64, b1_64, b2_64


def distance(p1, p2, p3=None, p4=None, radian=False):
    """ distance(p1, p2, p3=None, p4=None, radian=False) -> [m]

        distance((lat[deg], lon[deg]), (lat[deg], lon[deg])) -> [m]
        distance([lat[deg], lon[deg]],[lat[deg], lon[deg]]) -> [m]
        distance(lat[deg], lon[deg], lat[deg], lon[deg]) -> [m]
        distance(lat[rad], lon[rad], lat[rad], lon[rad], radian=True) -> [m]

        Computes the shortest distance between two positions defined by
        their latitudes and longitudes. The method (Vincenty) assumes a
        WGS84 Ellipsoidal Earth.

        As a reference, the minute of arc in latitude at the equator defines the
        nautical mile.

        >>> distance((0, 0), (0, 1./60))
        1855.3248463069199

        You can also call distance without forming pairs:
        >>> distance(0, 0, 0, 1./60)
        1855.3248463069199

        p1 and p2 can also be of any kind of iterable.
        The result is provided as a numpy array. (default dtype: numpy.float64)
        >>> size = 360 * 60 - 1
        >>> p1 = [(0, i / 60.) for i in range(size)]
        >>> p2 = [(0, (i + 1) / 60.) for i in range(size)]
        >>> d = distance(p1, p2)
        >>> "%.7f %.7f" % (np.min(d), np.max(d))
        '1855.3248463 1855.3248463'

        You can also iterate on lists of coordinates without forming pairs:
        >>> size = 360 * 60 - 1
        >>> p1 = [ 0 for i in range(size)]
        >>> p2 = [ i / 60. for i in range(size)]
        >>> p3 = [ 0 for i in range(size)]
        >>> p4 = [(i + 1) / 60. for i in range(size)]
        >>> d = distance(p1, p2, p3, p4)
        >>> "%.7f %.7f" % (np.min(d), np.max(d))
        '1855.3248463 1855.3248463'

    """
    d, b1, b2 = distance_bearing(p1, p2, p3, p4, radian)
    return d

def bearing(p1, p2, p3=None, p4=None, radian=False):
    """ bearing(p1, p2, p3=None, p4=None, radian=False) -> [deg/rad]

        bearing((lat[deg], lon[deg]), (lat[deg], lon[deg])) -> [deg]
        bearing([lat[deg], lon[deg]],[lat[deg], lon[deg]]) -> [deg]
        bearing(lat[deg], lon[deg], lat[deg], lon[deg]) -> [deg]
        bearing(lat[rad], lon[rad], lat[rad], lon[rad], radian=True) -> [rad]

        Computes the initial bearing (direction, azimuth) from position 1 to
        position 2 defined by their latitudes and longitudes, following a great
        circle. Note the bearing changes continously along a great circle. The
        method (Vincenty) assumes a WGS84 Ellipsoidal Earth.

        The following example shows the direction to the East.
        >>> bearing((0, 0), (0, 1./60))
        90.0

        You can also call bearing without forming pairs:
        >>> bearing(0, 0, 0, 1./60)
        90.0

        p1 and p2 can also be of any kind of iterable.
        The result is provided as a numpy array. (default dtype: numpy.float64)
        >>> size = 360 * 60 - 1
        >>> p1 = [(0, i / 60.) for i in range(size)]
        >>> p2 = [(0, (i + 1) / 60.) for i in range(size)]
        >>> b = bearing(p1, p2)
        >>> np.min(b), np.max(b)
        (90.0, 90.0)

        You can also iterate on lists of coordinates without forming pairs:
        >>> size = 360 * 60 - 1
        >>> p1 = [ 0 for i in range(size)]
        >>> p2 = [ i / 60. for i in range(size)]
        >>> p3 = [ 0 for i in range(size)]
        >>> p4 = [(i + 1) / 60. for i in range(size)]
        >>> d = bearing(p1, p2, p3, p4)
        >>> np.min(b), np.max(b)
        (90.0, 90.0)
    """
    d, b1, b2 = distance_bearing(p1, p2, p3, p4, radian)
    return b1

def destination(p, double bearing, double distance):
    """ destination(p [deg, deg], bearing [deg], distance [m])
                    -> ([deg, deg])
        Computes the destination point given a start position (lat, lon), an
        initial bearing and a distance using Vincenty inverse formula for
        ellipsoids.

        60 nm on the Equator correspond to one degree.
        >>> p = destination((0, 0), 90, 60 * 1855.32)
        >>> "%.5f %.5f" % p
        '0.00000 1.00000'
    """
    cdef double lat = radians*p[0], lon = radians*p[1]
    cdef double tolat = 0, tolon = 0, tmp = 0
    wgs84_destination(lat, lon, radians*bearing, distance, tolat, tolon, tmp)
    return (tolat/radians, tolon/radians)

