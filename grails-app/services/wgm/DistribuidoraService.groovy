package wgm

import grails.gorm.services.Service

@Service(Distribuidora)
interface DistribuidoraService {

    Distribuidora get(Serializable id)

    List<Distribuidora> list(Map args)

    Long count()

    void delete(Serializable id)

    Distribuidora save(Distribuidora distribuidora)

}